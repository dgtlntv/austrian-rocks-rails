# frozen_string_literal: true

require "aws-sdk-s3"
require "cgi"
require "pathname"
require "map_tiles/configuration"

module MapTiles
  class FontPublisher
    class Error < StandardError; end
    class ConfigurationError < Error; end
    class UploadError < Error; end

    PBF_CONTENT_TYPE = "application/x-protobuf"
    IMMUTABLE_CACHE_CONTROL = "public, max-age=31536000, immutable"
    REQUIRED_BUNNY_ENV = %w[
      BUNNY_STORAGE_ENDPOINT
      BUNNY_STORAGE_REGION
      BUNNY_STORAGE_BUCKET
      BUNNY_STORAGE_ACCESS_KEY_ID
      BUNNY_STORAGE_SECRET_ACCESS_KEY
    ].freeze

    attr_reader :configuration, :s3_client, :out

    def initialize(configuration: Configuration.new, s3_client: nil, out: $stdout)
      @configuration = configuration
      @s3_client = s3_client
      @out = out
    end

    def publish
      validate_configuration!

      uploads = upload_plan
      uploads.each { |upload| upload_object(upload) }
      uploads.each { |upload| out.puts "published #{upload.fetch(:key)} -> #{upload.fetch(:url)}" }
      uploads.map { |upload| { key: upload.fetch(:key), url: upload.fetch(:url) } }
    end

    private

    def validate_configuration!
      missing_bunny_env = REQUIRED_BUNNY_ENV.select { |name| configuration.env[name].to_s.strip.blank? }
      raise ConfigurationError, "Missing Bunny storage environment variable(s): #{missing_bunny_env.join(', ')}" if missing_bunny_env.any?

      raise ConfigurationError, "Configured public CDN host is required" if configuration.public_cdn_host.blank?
      raise ConfigurationError, "Configured style prefix must include at least one object key segment" if configuration.style_prefix.blank?
      raise ConfigurationError, "Configured font glyph root is missing: #{configuration.font_glyph_root}" unless configuration.font_glyph_root.directory?

      configuration.font_glyph_object_prefix
      configuration.font_glyphs_template_url
    rescue ArgumentError => e
      raise ConfigurationError, e.message
    end

    def upload_plan
      root = configuration.font_glyph_root.realpath
      pbf_paths = Dir.glob(root.join("**/*.pbf").to_s).map { |path| Pathname.new(path) }.sort_by { |path| path.to_s }
      raise ConfigurationError, "Font glyph root contains no PBF files: #{root}" if pbf_paths.empty?

      pbf_paths.map do |path|
        relative_path = safe_relative_path(path, root)
        key = [ configuration.font_glyph_object_prefix, relative_path ].join("/")
        {
          key: key,
          path: path.realpath,
          url: public_url_for_key(key),
          content_type: PBF_CONTENT_TYPE,
          cache_control: IMMUTABLE_CACHE_CONTROL
        }
      end
    end

    def safe_relative_path(path, root)
      real_path = path.realpath
      root_string = root.to_s
      real_string = real_path.to_s
      unless real_string.start_with?("#{root_string}#{File::SEPARATOR}")
        raise ConfigurationError, "Font glyph path escapes configured root: #{path}"
      end

      relative_path = real_path.relative_path_from(root).to_s
      segments = relative_path.split("/")
      raise ConfigurationError, "Font glyph object key contains empty path segments" if segments.any?(&:blank?)

      segments.each do |segment|
        raise ConfigurationError, "Font glyph object key must not contain path traversal segments" if %w[. ..].include?(segment)
        unless segment.match?(/\A[A-Za-z0-9 ._-]+\z/)
          raise ConfigurationError, "Font glyph object key segment contains unsafe characters: #{segment.inspect}"
        end
      end

      raise ConfigurationError, "Font glyph upload candidate must be a .pbf file: #{relative_path}" unless relative_path.end_with?(".pbf")

      relative_path
    rescue Errno::ENOENT
      raise ConfigurationError, "Font glyph path is missing: #{path}"
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
      raise UploadError, "Bunny font glyph upload failed for key #{upload.fetch(:key)} (#{e.class})"
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

    def public_url_for_key(key)
      escaped_key = key.split("/").map { |segment| CGI.escape(segment).gsub("+", "%20") }.join("/")
      "#{public_cdn_base}/#{escaped_key}"
    end

    def public_cdn_base
      configuration.font_glyphs_template_url.split("/#{configuration.font_glyph_object_prefix}/", 2).first
    end
  end
end
