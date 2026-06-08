# frozen_string_literal: true

require "pathname"
require "map_tiles/layer_contract"

module MapTiles
  class Configuration
    VERSION_REQUIRED_MESSAGE = "--version is required for build, smoke, and publish"

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
      prefix = fetch_setting("bunny_prefix").to_s.strip.gsub(%r{\A/+|/+\z}, "")
      return "" if prefix.blank?

      prefix.split("/").map do |segment|
        sanitize_path_segment(segment, name: "bunny_prefix")
      end.join("/")
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

    def versioned_object_key
      object_key("#{artifact_basename}-#{version}.pmtiles")
    end

    def latest_object_key
      object_key("#{artifact_basename}-latest.pmtiles")
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

    def object_key(file_name)
      [ bunny_prefix.presence, file_name ].compact.join("/")
    end

    def sanitize_path_segment(value, name:)
      segment = value.to_s.strip
      raise ArgumentError, "#{name} must contain only letters, numbers, dots, underscores, or dashes" unless segment.match?(/\A[A-Za-z0-9._-]+\z/)
      raise ArgumentError, "#{name} must not be a path traversal segment" if %w[. ..].include?(segment)

      segment
    end
  end
end
