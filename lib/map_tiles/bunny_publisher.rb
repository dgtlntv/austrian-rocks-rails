# frozen_string_literal: true

require "aws-sdk-s3"
require "json"
require "net/http"
require "stringio"
require "uri"
require "map_tiles/configuration"

module MapTiles
  class BunnyPublisher
    class Error < StandardError; end
    class ConfigurationError < Error; end
    class UploadError < Error; end
    class VerificationError < Error; end

    PMTILES_CONTENT_TYPE = "application/octet-stream"
    REQUIRED_BUNNY_ENV = %w[
      BUNNY_STORAGE_ENDPOINT
      BUNNY_STORAGE_REGION
      BUNNY_STORAGE_BUCKET
      BUNNY_STORAGE_ACCESS_KEY_ID
      BUNNY_STORAGE_SECRET_ACCESS_KEY
    ].freeze
    attr_reader :configuration, :s3_client, :http_head, :out, :clock

    def initialize(configuration: Configuration.new, s3_client: nil, http_head: nil, out: $stdout, clock: -> { Time.current })
      @configuration = configuration
      @s3_client = s3_client
      @http_head = http_head || method(:net_http_head)
      @out = out
      @clock = clock
    end

    def publish
      validate_configuration!
      artifact_path = configuration.artifact_path
      raise ConfigurationError, "PMTiles artifact is missing: #{artifact_path}" unless artifact_path.exist?
      raise ConfigurationError, "PMTiles artifact is empty: #{artifact_path}" unless artifact_path.size.positive?

      pmtiles_key = configuration.versioned_object_key
      upload_pmtiles_object(pmtiles_key, artifact_path)
      pmtiles_url = public_url_for(pmtiles_key)
      verify_public_url!(pmtiles_url)

      manifest_key = configuration.latest_manifest_object_key
      manifest_body = manifest_json(pmtiles_url: pmtiles_url, pmtiles_object_key: pmtiles_key)
      # latest.json is the only overwritten object; overwriting PMTiles archives can produce stale or mixed range responses.
      upload_manifest_object(manifest_key, manifest_body)
      manifest_url = public_url_for(manifest_key)
      verify_public_url!(manifest_url)

      published = {
        pmtiles: { key: pmtiles_key, url: pmtiles_url },
        manifest: { key: manifest_key, url: manifest_url }
      }

      out.puts "published #{pmtiles_key} -> #{pmtiles_url}"
      out.puts "published #{manifest_key} -> #{manifest_url}"
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
      configuration.latest_manifest_object_key
    rescue ArgumentError => e
      raise ConfigurationError, e.message
    end

    def upload_pmtiles_object(key, artifact_path)
      File.open(artifact_path, "rb") do |body|
        upload_object(
          key: key,
          body: body,
          content_type: PMTILES_CONTENT_TYPE,
          cache_control: configuration.pmtiles_cache_control
        )
      end
    end

    def upload_manifest_object(key, manifest_body)
      upload_object(
        key: key,
        body: StringIO.new(manifest_body),
        content_type: configuration.manifest_content_type,
        cache_control: "public, max-age=#{configuration.manifest_cache_ttl_seconds}"
      )
    end

    def upload_object(key:, body:, content_type:, cache_control:)
      client.put_object(
        bucket: configuration.env.fetch("BUNNY_STORAGE_BUCKET"),
        key: key,
        body: body,
        content_type: content_type,
        cache_control: cache_control
      )
    rescue Aws::Errors::ServiceError, SystemCallError => e
      raise UploadError, "Bunny PMTiles upload failed for key #{key} (#{e.class})"
    end

    def manifest_json(pmtiles_url:, pmtiles_object_key:)
      JSON.generate(
        version: configuration.version,
        pmtiles_url: pmtiles_url,
        published_at: clock.call.utc.iso8601,
        artifact_basename: configuration.artifact_basename,
        pmtiles_object_key: pmtiles_object_key,
        pmtiles_object_basename: File.basename(pmtiles_object_key)
      )
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

    def public_url_for(key)
      "#{public_cdn_base}/#{key}"
    end

    def public_cdn_base
      host = configuration.public_cdn_host.to_s.delete_suffix("/")
      host.match?(%r{\Ahttps?://}i) ? host : "https://#{host}"
    end

    def verify_public_url!(url)
      response = http_head.call(URI.parse(url))
      status = response_status(response)
      return if status&.between?(200, 299)

      raise VerificationError, "Bunny PMTiles public URL failed HEAD check: #{url} returned #{status || 'unknown status'}"
    rescue URI::InvalidURIError => e
      raise VerificationError, "Bunny PMTiles public URL is invalid: #{url} (#{e.message})"
    rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, SystemCallError => e
      raise VerificationError, "Bunny PMTiles public URL failed HEAD check: #{url} (#{e.class})"
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
