# frozen_string_literal: true

require "pathname"
require "uri"
require "map_tiles/layer_contract"

module MapTiles
  class Configuration
    VERSION_REQUIRED_MESSAGE = "--version is required for build, smoke, and publish"
    STYLE_NAMES = %w[light dark].freeze

    attr_reader :env

    def initialize(version: nil, env: ENV, settings: nil)
      @version = version
      @env = env
      @settings = normalize_settings(settings || Rails.application.config_for(:map_tiles))
    end

    def with_version(version)
      self.class.new(version: version, env: env, settings: settings)
    end

    def output_dir
      Rails.root.join(fetch_setting("output_dir"))
    end

    def geojson_dir
      output_dir.join("geojson")
    end

    def artifact_basename
      sanitize_path_segment(fetch_setting("artifact_basename"), name: "artifact_basename")
    end

    def version
      require_version!
      sanitize_path_segment(@version, name: "--version")
    end

    def public_cdn_host
      fetch_setting("public_cdn_host").to_s.strip.presence
    end

    def bunny_prefix
      sanitized_prefix("bunny_prefix")
    end

    def style_prefix
      sanitized_prefix("style_prefix")
    end

    def manifest_prefix
      sanitized_prefix("manifest_prefix")
    end

    def manifest_object_name
      object_name = sanitize_path_segment(fetch_setting("manifest_object_name"), name: "manifest_object_name")
      raise ArgumentError, "manifest_object_name must end in .json" unless object_name.end_with?(".json")

      object_name
    end

    def default_style
      sanitize_style_name(fetch_setting("default_style"), name: "default_style")
    end

    def terrain_opacity
      opacity = Float(fetch_setting("terrain_opacity"))
      raise ArgumentError, "terrain_opacity must be between 0 and 1" unless opacity.between?(0.0, 1.0)

      opacity
    rescue TypeError, ArgumentError
      raise ArgumentError, "terrain_opacity must be between 0 and 1"
    end

    def basemap_at_style_url
      fetch_setting("basemap_at_style_url").to_s.strip
    end

    def basemap_at_attribution
      fetch_setting("basemap_at_attribution").to_s.strip
    end

    def optional_production_layers
      layers = Array(settings.fetch("optional_production_layers", [])).map do |layer_name|
        sanitize_path_segment(layer_name, name: "optional_production_layers")
      end
      unknown_layers = layers - LayerContract.layer_names
      raise ArgumentError, "Unknown optional production layer(s): #{unknown_layers.join(', ')}" if unknown_layers.any?

      layers
    end

    def artifact_path
      output_dir.join("#{artifact_basename}-#{version}.pmtiles")
    end

    def metadata_path
      output_dir.join("#{artifact_basename}-#{version}.metadata.json")
    end

    def style_template_path(style_name)
      Rails.root.join("config/map_styles/austrian_rocks_#{sanitize_style_name(style_name)}.json")
    end

    def style_artifact_path(style_name)
      output_dir.join("#{artifact_basename}-#{version}-#{sanitize_style_name(style_name)}.json")
    end

    def manifest_artifact_path
      output_dir.join(manifest_object_name)
    end

    def versioned_object_key
      object_key(bunny_prefix, "#{artifact_basename}-#{version}.pmtiles")
    end

    def style_object_key(style_name)
      object_key(style_prefix, "#{artifact_basename}-#{version}-#{sanitize_style_name(style_name)}.json")
    end

    def manifest_object_key
      object_key(manifest_prefix, manifest_object_name)
    end

    def public_url_for_object_key(key)
      sanitized_key = key.to_s.split("/").map do |segment|
        sanitize_path_segment(segment, name: "object_key")
      end.join("/")

      "#{public_cdn_base}/#{sanitized_key}"
    end

    def pmtiles_public_url
      public_url_for_object_key(versioned_object_key)
    end

    def style_public_url(style_name)
      public_url_for_object_key(style_object_key(style_name))
    end

    def manifest_public_url
      public_url_for_object_key(manifest_object_key)
    end

    def expected_layers
      LayerContract.layer_names
    end

    private

    attr_reader :settings

    def normalize_settings(raw_settings)
      raw_settings.to_h.transform_keys(&:to_s)
    end

    def fetch_setting(name)
      value = settings.fetch(name)
      value.is_a?(String) ? value.strip : value
    end

    def require_version!
      return if @version.to_s.strip.present?

      raise ArgumentError, VERSION_REQUIRED_MESSAGE
    end

    def object_key(prefix, file_name)
      [ prefix.presence, file_name ].compact.join("/")
    end

    def sanitized_prefix(name)
      prefix = fetch_setting(name).to_s.strip.gsub(%r{\A/+|/+\z}, "")
      return "" if prefix.blank?

      prefix.split("/").map do |segment|
        sanitize_path_segment(segment, name: name)
      end.join("/")
    end

    def sanitize_style_name(style_name, name: "style_name")
      style = style_name.to_s.strip
      raise ArgumentError, "#{name} must be one of: #{STYLE_NAMES.join(', ')}" unless STYLE_NAMES.include?(style)

      style
    end

    def public_cdn_base
      host = public_cdn_host.to_s.delete_suffix("/")
      raise ArgumentError, "public_cdn_host is required" if host.blank?

      uri = URI.parse(host.match?(%r{\Ahttps?://}i) ? host : "https://#{host}")
      raise ArgumentError, "public_cdn_host must use https" unless uri.scheme == "https"
      raise ArgumentError, "public_cdn_host must not contain credentials" if uri.userinfo.present?
      raise ArgumentError, "public_cdn_host must not contain a path" if uri.path.present? && uri.path != "/"

      uri.to_s.delete_suffix("/")
    rescue URI::InvalidURIError => e
      raise ArgumentError, "public_cdn_host is invalid: #{e.message}"
    end

    def sanitize_path_segment(value, name:)
      segment = value.to_s.strip
      raise ArgumentError, "#{name} must contain only letters, numbers, dots, underscores, or dashes" unless segment.match?(/\A[A-Za-z0-9._-]+\z/)
      raise ArgumentError, "#{name} must not be a path traversal segment" if %w[. ..].include?(segment)

      segment
    end
  end
end
