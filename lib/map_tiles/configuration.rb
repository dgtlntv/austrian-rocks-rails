# frozen_string_literal: true

require "pathname"
require "uri"
require "map_tiles/layer_contract"

module MapTiles
  class Configuration
    VERSION_REQUIRED_MESSAGE = "--version is required for build, smoke, and publish"
    STYLE_NAMES = %w[light dark].freeze
    SPRITE_SUFFIXES = [ ".png", ".json", "@2x.png", "@2x.json" ].freeze

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

    def font_glyph_subpath
      sanitized_subpath("font_glyph_subpath")
    end

    def font_glyph_root
      Rails.root.join("config/map_styles", font_glyph_subpath)
    end

    def font_glyph_object_prefix
      object_key(style_prefix, font_glyph_subpath)
    end

    def font_glyphs_template_url
      "#{public_cdn_base}/#{font_glyph_object_prefix}/{fontstack}/{range}.pbf"
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
      opacity_setting("terrain_opacity")
    end

    def contour_opacity
      opacity_setting("contour_opacity")
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

    def automatic_publish_debounce
      fetch_setting("automatic_publish_debounce_minutes").to_i.minutes
    end

    def manifest_cache_ttl_seconds
      fetch_setting("manifest_cache_ttl_seconds").to_i
    end

    def pmtiles_cache_control
      fetch_setting("pmtiles_cache_control").to_s.strip
    end

    def manifest_content_type
      fetch_setting("manifest_content_type").to_s.strip
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

    # The four sprite artifacts share one versioned basename; MapLibre clients
    # receive only the extensionless base URL and append .png/.json/@2x themselves.
    def sprite_basename
      "#{artifact_basename}-#{version}-sprite"
    end

    def sprite_artifact_path(suffix)
      output_dir.join("#{sprite_basename}#{sprite_suffix(suffix)}")
    end

    def sprite_object_key(suffix)
      object_key(style_prefix, "#{sprite_basename}#{sprite_suffix(suffix)}")
    end

    def sprite_public_url(suffix)
      "#{sprite_public_base_url}#{sprite_suffix(suffix)}"
    end

    def sprite_public_base_url
      public_url_for_object_key(object_key(style_prefix, sprite_basename))
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
      raw_key = key.to_s.strip
      raise ArgumentError, "object_key is required" if raw_key.blank?
      raise ArgumentError, "object_key must not contain empty path segments" if raw_key.start_with?("/") || raw_key.end_with?("/") || raw_key.include?("//")

      sanitized_key = raw_key.split("/").map do |segment|
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

    # "@2x" makes the sprite suffixes the one object-key fragment the generic
    # path-segment sanitizer cannot pass, so they come from a closed allowlist.
    def sprite_suffix(suffix)
      raise ArgumentError, "sprite suffix must be one of: #{SPRITE_SUFFIXES.join(', ')}" unless SPRITE_SUFFIXES.include?(suffix)

      suffix
    end

    def sanitized_prefix(name)
      prefix = fetch_setting(name).to_s.strip.gsub(%r{\A/+|/+\z}, "")
      return "" if prefix.blank?

      prefix.split("/").map do |segment|
        sanitize_path_segment(segment, name: name)
      end.join("/")
    end

    def sanitized_subpath(name)
      subpath = fetch_setting(name).to_s.strip
      raise ArgumentError, "#{name} is required" if subpath.blank?
      raise ArgumentError, "#{name} must not start or end with a slash" if subpath.start_with?("/") || subpath.end_with?("/")

      segments = subpath.split("/")
      raise ArgumentError, "#{name} must not contain empty path segments" if segments.any?(&:blank?)

      segments.map do |segment|
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
      raise ArgumentError, "public_cdn_host must not contain query parameters" if uri.query.present?
      raise ArgumentError, "public_cdn_host must not contain a fragment" if uri.fragment.present?

      uri.to_s.delete_suffix("/")
    rescue URI::InvalidURIError => e
      raise ArgumentError, "public_cdn_host is invalid: #{e.message}"
    end

    def opacity_setting(name)
      opacity = Float(fetch_setting(name))
      raise ArgumentError, "#{name} must be between 0 and 1" unless opacity.between?(0.0, 1.0)

      opacity
    rescue TypeError, ArgumentError
      raise ArgumentError, "#{name} must be between 0 and 1"
    end

    def sanitize_path_segment(value, name:)
      segment = value.to_s.strip
      raise ArgumentError, "#{name} must contain only letters, numbers, dots, underscores, or dashes" unless segment.match?(/\A[A-Za-z0-9._-]+\z/)
      raise ArgumentError, "#{name} must not be a path traversal segment" if %w[. ..].include?(segment)

      segment
    end
  end
end
