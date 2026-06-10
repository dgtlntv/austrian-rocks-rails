# frozen_string_literal: true

require "fileutils"
require "json"
require "map_tiles/configuration"

module MapTiles
  class StyleMaterializer
    class Error < StandardError; end

    SOURCE_NAME = "austrian-rocks"
    CONTOUR_SOURCE_NAME = "basemap-at-hoehenlinien"
    TERRAIN_LAYER_ID = "gelände"

    attr_reader :configuration

    def initialize(configuration: Configuration.new)
      @configuration = configuration
    end

    def materialize
      Configuration::STYLE_NAMES.to_h do |style_name|
        style = read_style_template(style_name)
        apply_configured_opacity!(style)
        validate_style!(style, style_name)
        style.fetch("sources").fetch(SOURCE_NAME)["url"] = "pmtiles://#{configuration.pmtiles_public_url}"

        path = configuration.style_artifact_path(style_name)
        FileUtils.mkdir_p(path.dirname)
        path.write(JSON.generate(style))

        [ style_name, path ]
      end
    end

    private

    def read_style_template(style_name)
      JSON.parse(configuration.style_template_path(style_name).read)
    rescue JSON::ParserError => e
      raise Error, "#{style_name} style JSON is invalid: #{e.message}"
    end

    def apply_configured_opacity!(style)
      Array(style["layers"]).each do |layer|
        paint = layer["paint"]
        next unless paint.is_a?(Hash)

        paint["raster-opacity"] = configuration.terrain_opacity if layer.fetch("id", "").casecmp(TERRAIN_LAYER_ID).zero?
        next unless layer["source"] == CONTOUR_SOURCE_NAME

        paint["line-opacity"] = configuration.contour_opacity if layer["type"] == "line"
        paint["text-opacity"] = configuration.contour_opacity if layer["type"] == "symbol"
      end
    end

    def validate_style!(style, style_name)
      raise Error, "#{style_name} style must be MapLibre style version 8" unless style["version"] == 8
      raise Error, "#{style_name} style must define sources" unless style["sources"].is_a?(Hash)
      raise Error, "#{style_name} style must define layers" unless style["layers"].is_a?(Array)
      raise Error, "#{style_name} style must define #{SOURCE_NAME} source" unless style.fetch("sources").key?(SOURCE_NAME)

      assert_layer_contract_coverage!(style, style_name)
    end

    def assert_layer_contract_coverage!(style, style_name)
      styled_source_layers = style.fetch("layers").filter_map do |layer|
        layer["source-layer"] if layer["source"] == SOURCE_NAME
      end.uniq
      missing_layers = LayerContract.layer_names - styled_source_layers
      return if missing_layers.empty?

      raise Error, "#{style_name} style is missing Austrian Rocks source layer style(s): #{missing_layers.join(', ')}"
    end
  end
end
