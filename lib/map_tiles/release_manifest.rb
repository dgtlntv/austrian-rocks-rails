# frozen_string_literal: true

require "fileutils"
require "json"
require "time"
require "uri"
require "map_tiles/configuration"

module MapTiles
  # Writes the non-cached map release manifest. The manifest is the only mutable
  # publication pointer; PMTiles and style JSON URLs are immutable versioned
  # objects so clients can cache them aggressively and roll back by republishing
  # this small JSON document.
  class ReleaseManifest
    class Error < StandardError; end

    attr_reader :configuration, :clock

    def initialize(configuration: Configuration.new, clock: -> { Time.current })
      @configuration = configuration
      @clock = clock
    end

    def write
      manifest = build_manifest
      path = configuration.manifest_artifact_path
      FileUtils.mkdir_p(path.dirname)
      path.write(JSON.generate(manifest))
      path
    end

    private

    def build_manifest
      version = configuration.version
      pmtiles_url = validated_public_url(configuration.pmtiles_public_url, name: "pmtilesUrl")
      sprite_url = validated_public_url(configuration.sprite_public_base_url, name: "spriteUrl")
      styles = Configuration::STYLE_NAMES.to_h do |style_name|
        [ style_name, validated_public_url(configuration.style_public_url(style_name), name: "styles.#{style_name}") ]
      end

      {
        "version" => version,
        "pmtilesUrl" => pmtiles_url,
        "spriteUrl" => sprite_url,
        "styles" => styles,
        "publishedAt" => published_at
      }.tap { |manifest| validate_no_credentials!(manifest) }
    rescue ArgumentError => e
      raise Error, e.message
    end

    def published_at
      clock.call.utc.iso8601
    end

    def validated_public_url(value, name:)
      url = value.to_s
      uri = URI.parse(url)
      raise Error, "#{name} must be an HTTP(S) URL" unless %w[http https].include?(uri.scheme)
      raise Error, "#{name} must include a host" if uri.host.blank?
      raise Error, "#{name} must not contain credentials" if uri.userinfo.present?

      url
    rescue URI::InvalidURIError => e
      raise Error, "#{name} is invalid: #{e.message}"
    end

    def validate_no_credentials!(manifest)
      urls = [ manifest.fetch("pmtilesUrl"), manifest.fetch("spriteUrl"), *manifest.fetch("styles").values ]
      return if urls.none? { |url| URI.parse(url).userinfo.present? }

      raise Error, "release manifest must not contain credentials"
    end
  end
end
