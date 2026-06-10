# frozen_string_literal: true

require "aws-sdk-s3"
require "net/http"
require "uri"
require "map_tiles/configuration"
require "map_tiles/release_manifest"
require "map_tiles/sprite_builder"
require "map_tiles/style_materializer"

module MapTiles
  class BunnyPublisher
    class Error < StandardError; end
    class ConfigurationError < Error; end
    class UploadError < Error; end
    class VerificationError < Error; end

    PMTILES_CONTENT_TYPE = "application/octet-stream"
    JSON_CONTENT_TYPE = "application/json; charset=utf-8"
    PNG_CONTENT_TYPE = "image/png"
    IMMUTABLE_CACHE_CONTROL = "public, max-age=31536000, immutable"
    MANIFEST_CACHE_CONTROL = "no-cache, max-age=0, must-revalidate"
    REQUIRED_BUNNY_ENV = %w[
      BUNNY_STORAGE_ENDPOINT
      BUNNY_STORAGE_REGION
      BUNNY_STORAGE_BUCKET
      BUNNY_STORAGE_ACCESS_KEY_ID
      BUNNY_STORAGE_SECRET_ACCESS_KEY
    ].freeze
    attr_reader :configuration, :s3_client, :http_head, :out, :style_materializer, :sprite_builder, :release_manifest

    def initialize(configuration: Configuration.new, s3_client: nil, http_head: nil, out: $stdout, style_materializer: nil, sprite_builder: nil, release_manifest: nil)
      @configuration = configuration
      @s3_client = s3_client
      @http_head = http_head || method(:net_http_head)
      @out = out
      @style_materializer = style_materializer || StyleMaterializer.new(configuration: configuration)
      @sprite_builder = sprite_builder || SpriteBuilder.new(configuration: configuration)
      @release_manifest = release_manifest || ReleaseManifest.new(configuration: configuration)
    end

    def publish
      validate_configuration!
      pmtiles_path = configuration.artifact_path
      validate_artifact!(pmtiles_path, "PMTiles")

      style_paths = style_materializer.materialize
      sprite_paths = sprite_builder.build
      manifest_path = release_manifest.write
      uploads = upload_plan(pmtiles_path: pmtiles_path, style_paths: style_paths, sprite_paths: sprite_paths, manifest_path: manifest_path)
      uploads.each { |upload| validate_artifact!(upload.fetch(:path), upload.fetch(:label)) }

      versioned_uploads, manifest_upload = split_upload_plan(uploads)
      versioned_uploads.each { |upload| upload_object(upload) }
      versioned_uploads.each { |upload| verify_public_url!(upload.fetch(:url)) }
      upload_object(manifest_upload)
      verify_public_url!(manifest_upload.fetch(:url))

      published = (versioned_uploads + [ manifest_upload ]).map { |upload| { key: upload.fetch(:key), url: upload.fetch(:url) } }
      published.each { |object| out.puts "published #{object.fetch(:key)} -> #{object.fetch(:url)}" }
      published
    end

    private

    def validate_configuration!
      missing_bunny_env = REQUIRED_BUNNY_ENV.select { |name| configuration.env[name].to_s.strip.blank? }
      raise ConfigurationError, "Missing Bunny storage environment variable(s): #{missing_bunny_env.join(', ')}" if missing_bunny_env.any?

      raise ConfigurationError, "Configured public CDN host is required" if configuration.public_cdn_host.blank?
      raise ConfigurationError, "Configured Bunny prefix must include at least one object key segment" if configuration.bunny_prefix.blank?

      configuration.artifact_basename
      configuration.versioned_object_key
      configuration.style_object_key("light")
      configuration.style_object_key("dark")
      configuration.manifest_object_key
      configuration.pmtiles_public_url
      configuration.style_public_url("light")
      configuration.style_public_url("dark")
      configuration.manifest_public_url
      configuration.sprite_public_base_url
      Configuration::SPRITE_SUFFIXES.each do |suffix|
        configuration.sprite_object_key(suffix)
        configuration.sprite_public_url(suffix)
      end
    rescue ArgumentError => e
      raise ConfigurationError, e.message
    end

    def validate_artifact!(path, label)
      raise ConfigurationError, "#{label} artifact is missing: #{path}" unless path.exist?
      raise ConfigurationError, "#{label} artifact is empty: #{path}" unless path.size.positive?
    end

    def split_upload_plan(uploads)
      manifest_upload = uploads.find { |upload| upload.fetch(:key) == configuration.manifest_object_key }
      versioned_uploads = uploads.reject { |upload| upload.equal?(manifest_upload) }
      raise ConfigurationError, "Manifest upload is missing from map release upload plan" unless manifest_upload

      [ versioned_uploads, manifest_upload ]
    end

    def upload_plan(pmtiles_path:, style_paths:, sprite_paths:, manifest_path:)
      [
        {
          label: "PMTiles",
          key: configuration.versioned_object_key,
          path: pmtiles_path,
          url: configuration.pmtiles_public_url,
          content_type: PMTILES_CONTENT_TYPE,
          cache_control: IMMUTABLE_CACHE_CONTROL
        },
        {
          label: "light style",
          key: configuration.style_object_key("light"),
          path: style_paths.fetch("light"),
          url: configuration.style_public_url("light"),
          content_type: JSON_CONTENT_TYPE,
          cache_control: IMMUTABLE_CACHE_CONTROL
        },
        {
          label: "dark style",
          key: configuration.style_object_key("dark"),
          path: style_paths.fetch("dark"),
          url: configuration.style_public_url("dark"),
          content_type: JSON_CONTENT_TYPE,
          cache_control: IMMUTABLE_CACHE_CONTROL
        },
        *sprite_upload_plan(sprite_paths),
        {
          label: "manifest",
          key: configuration.manifest_object_key,
          path: manifest_path,
          url: configuration.manifest_public_url,
          content_type: JSON_CONTENT_TYPE,
          cache_control: MANIFEST_CACHE_CONTROL
        }
      ]
    rescue KeyError => e
      raise ConfigurationError, "Map release build did not produce the #{e.key.inspect} artifact"
    end

    # The sprite ships as four versioned immutable objects beside the styles so
    # they upload and HEAD-verify before the manifest pointer moves.
    def sprite_upload_plan(sprite_paths)
      Configuration::SPRITE_SUFFIXES.map do |suffix|
        {
          label: "sprite#{suffix}",
          key: configuration.sprite_object_key(suffix),
          path: sprite_paths.fetch("sprite#{suffix}"),
          url: configuration.sprite_public_url(suffix),
          content_type: suffix.end_with?(".png") ? PNG_CONTENT_TYPE : JSON_CONTENT_TYPE,
          cache_control: IMMUTABLE_CACHE_CONTROL
        }
      end
    end

    def upload_object(upload)
      File.open(upload.fetch(:path), "rb") do |body|
        client.put_object(
          bucket: configuration.env.fetch("BUNNY_STORAGE_BUCKET"),
          key: upload.fetch(:key),
          body: body,
          content_type: upload.fetch(:content_type),
          cache_control: upload.fetch(:cache_control)
        )
      end
    rescue Aws::Errors::ServiceError, SystemCallError => e
      raise UploadError, "Bunny map release upload failed for key #{upload.fetch(:key)} (#{e.class})"
    end

    def client
      @s3_client ||= Aws::S3::Client.new(
        endpoint: configuration.env.fetch("BUNNY_STORAGE_ENDPOINT"),
        region: configuration.env.fetch("BUNNY_STORAGE_REGION"),
        access_key_id: configuration.env.fetch("BUNNY_STORAGE_ACCESS_KEY_ID"),
        secret_access_key: configuration.env.fetch("BUNNY_STORAGE_SECRET_ACCESS_KEY"),
        force_path_style: true
      )
    end

    def verify_public_url!(url)
      response = http_head.call(URI.parse(url))
      status = response_status(response)
      return if status&.between?(200, 299)

      raise VerificationError, "Bunny map release public URL failed HEAD check: #{url} returned #{status || 'unknown status'}"
    rescue URI::InvalidURIError => e
      raise VerificationError, "Bunny map release public URL is invalid: #{url} (#{e.message})"
    rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, SystemCallError => e
      raise VerificationError, "Bunny map release public URL failed HEAD check: #{url} (#{e.class})"
    end

    def response_status(response)
      if response.respond_to?(:code)
        response.code.to_i
      elsif response.respond_to?(:status)
        response.status.to_i
      end
    end

    def net_http_head(uri)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.head(uri.request_uri)
      end
    end
  end
end
