# frozen_string_literal: true

require "pathname"
require "map_tiles/layer_contract"

module MapTiles
  class Configuration
    ARTIFACT_BASENAME = "austrian-rocks"
    DEFAULT_OUTPUT_DIR = "tmp/map_tiles"

    attr_reader :env

    def initialize(env: ENV)
      @env = env
    end

    def output_dir
      Rails.root.join(env.fetch("MAP_TILES_OUTPUT_DIR", DEFAULT_OUTPUT_DIR))
    end

    def geojson_dir
      output_dir.join("geojson")
    end

    def artifact_basename
      ARTIFACT_BASENAME
    end

    def version
      env.fetch("MAP_TILES_VERSION", "dev")
    end

    def public_cdn_host
      env["MAP_TILES_PUBLIC_CDN_HOST"].to_s.strip.presence
    end

    def bunny_prefix
      env.fetch("MAP_TILES_BUNNY_PREFIX", "map_tiles").to_s.strip.gsub(%r{\A/+|/+\z}, "")
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

    def object_key(file_name)
      [ bunny_prefix.presence, file_name ].compact.join("/")
    end
  end
end
