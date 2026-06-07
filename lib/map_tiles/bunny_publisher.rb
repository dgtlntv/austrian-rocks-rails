# frozen_string_literal: true

require "aws-sdk-s3"
require "net/http"
require "uri"
require "map_tiles/configuration"

module MapTiles
  class BunnyPublisher
    class Error < StandardError; end
    class ConfigurationError < Error; end
    class UploadError < Error; end
    class VerificationError < Error; end

    CONTENT_TYPE = "application/octet-stream"
    REQUIRED_BUNNY_ENV = %w[
      BUNNY_STORAGE_ENDPOINT
      BUNNY_STORAGE_REGION
      BUNNY_STORAGE_BUCKET
      BUNNY_STORAGE_ACCESS_KEY_ID
      BUNNY_STORAGE_SECRET_ACCESS_KEY
    ].freeze
    REQUIRED_MAP_ENV = %w[
      MAP_TILES_PUBLIC_CDN_HOST
      MAP_TILES_BUNNY_PREFIX
      MAP_TILES_VERSION
    ].freeze

    attr_reader :configuration, :s3_client, :http_head, :out

    def initialize(configuration: Configuration.new, s3_client: nil, http_head: nil, out: $stdout)
      @configuration = configuration
      @s3_client = s3_client
      @http_head = http_head || method(:net_http_head)
      @out = out
    end

    def publish
      validate_configuration!
      artifact_path = configuration.artifact_path
      raise ConfigurationError, "PMTiles artifact is missing: #{artifact_path}" unless artifact_path.exist?
      raise ConfigurationError, "PMTiles artifact is empty: #{artifact_path}" unless artifact_path.size.positive?

      object_keys = [ configuration.versioned_object_key, configuration.latest_object_key ]
      object_keys.each { |key| upload_object(key, artifact_path) }

      published = object_keys.map do |key|
        url = public_url_for(key)
        verify_public_url!(url)
        { key: key, url: url }
      end

      published.each { |object| out.puts "published #{object.fetch(:key)} -> #{object.fetch(:url)}" }
      published
    end

    private

    def validate_configuration!
      missing = (REQUIRED_MAP_ENV + REQUIRED_BUNNY_ENV).select { |name| configuration.env[name].to_s.strip.blank? }
      raise ConfigurationError, "Missing map tile publication environment variable(s): #{missing.join(', ')}" if missing.any?

      raise ConfigurationError, "MAP_TILES_BUNNY_PREFIX must include at least one object key segment" if configuration.bunny_prefix.blank?

      configuration.versioned_object_key
      configuration.latest_object_key
    rescue ArgumentError => e
      raise ConfigurationError, e.message
    end

    def upload_object(key, artifact_path)
      File.open(artifact_path, "rb") do |body|
        client.put_object(
          bucket: configuration.env.fetch("BUNNY_STORAGE_BUCKET"),
          key: key,
          body: body,
          content_type: CONTENT_TYPE
        )
      end
    rescue Aws::Errors::ServiceError, SystemCallError => e
      raise UploadError, "Bunny PMTiles upload failed for key #{key} (#{e.class})"
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
