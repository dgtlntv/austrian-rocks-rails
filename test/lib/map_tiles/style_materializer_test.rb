# frozen_string_literal: true

require "test_helper"
require "json"
require "securerandom"
require "tmpdir"
require "map_tiles/style_materializer"

class MapTiles::StyleMaterializerTest < ActiveSupport::TestCase
  setup do
    @output_dir = Rails.root.join("tmp/style_materializer_test/#{SecureRandom.hex(8)}")
    @configuration = MapTiles::Configuration.new(version: "2026-06-09", settings: map_tile_settings)
  end

  teardown do
    FileUtils.rm_rf(@output_dir)
  end

  test "committed light and dark styles are valid MapLibre templates" do
    %w[light dark].each do |style_name|
      style = read_template(style_name)

      assert_equal 8, style.fetch("version")
      assert_equal "Austrian Rocks #{style_name.titleize}", style.fetch("name")
      assert style.fetch("sources").key?("austrian-rocks")
      assert_equal "pmtiles://https://tiles.austrian.rocks/map_tiles/e2e/austrian-rocks-dev.pmtiles", style.dig("sources", "austrian-rocks", "url")
      assert_absolute_basemap_at_vector_tiles(style)
      assert_bergwerk_basemap_style_metadata(style)
      assert_basemap_at_contours(style, style_name)
      assert_no_mapbox_urls(style)
      assert_required_basemap_at_attribution(style)
      assert_no_open_street_map_attribution(style)
      assert_terrain_opacity(style)
      assert_austrian_rocks_overlay_zoom_hierarchy(style)
      assert_all_layer_contract_source_layers_are_styled(style)
    end
  end

  test "materializes versioned style artifacts with exact PMTiles public URL" do
    paths = MapTiles::StyleMaterializer.new(configuration: @configuration).materialize

    assert_equal %w[dark light], paths.keys.sort
    %w[light dark].each do |style_name|
      path = paths.fetch(style_name)
      assert_equal @configuration.style_artifact_path(style_name), path
      assert_predicate path, :exist?

      materialized = JSON.parse(path.read)
      assert_equal "pmtiles://#{@configuration.pmtiles_public_url}", materialized.dig("sources", "austrian-rocks", "url")
      assert_absolute_basemap_at_vector_tiles(materialized)
      assert_bergwerk_basemap_style_metadata(materialized)
      assert_basemap_at_contours(materialized, style_name)
      assert_no_mapbox_urls(materialized)
      assert_required_basemap_at_attribution(materialized)
      assert_no_open_street_map_attribution(materialized)
      assert_terrain_opacity(materialized)
      assert_austrian_rocks_overlay_zoom_hierarchy(materialized)
      assert_all_layer_contract_source_layers_are_styled(materialized)
    end
  end

  test "fails when a committed style does not cover every layer contract source layer" do
    Dir.mktmpdir("style-materializer") do |dir|
      style = read_template("light")
      style.fetch("layers").reject! { |layer| layer["source"] == "austrian-rocks" && layer["source-layer"] == "pois" }
      Pathname(dir).join("austrian_rocks_light.json").write(JSON.generate(style))
      FileUtils.cp(@configuration.style_template_path("dark"), Pathname(dir).join("austrian_rocks_dark.json"))
      configuration = FakeTemplateConfiguration.new(@configuration, Pathname(dir))

      error = assert_raises(MapTiles::StyleMaterializer::Error) do
        MapTiles::StyleMaterializer.new(configuration: configuration).materialize
      end

      assert_includes error.message, "pois"
    end
  end

  private

  def read_template(style_name)
    JSON.parse(@configuration.style_template_path(style_name).read)
  end

  def assert_absolute_basemap_at_vector_tiles(style)
    assert_not style.fetch("sources").key?("es" + "ri"), "basemap.at source should not retain confusing upstream source id"

    source = style.fetch("sources").fetch("basemap-at")
    assert_nil source["url"], "basemap.at vector source must not depend on a runtime TileJSON request"
    assert_equal [ "https://basemap.bergwerk-gis.at/api/tiles/basemap-at-vector/{z}/{x}/{y}.pbf" ], source.fetch("tiles")
    assert_not_includes source.fetch("tiles").join(" "), "/basemap-download/webapp/api/tiles/"
    assert_equal 0, source.fetch("minzoom")
    # Bergwerk serves vector tiles only up to z16 (410 Gone above); MapLibre overzooms beyond.
    assert_equal 16, source.fetch("maxzoom")
    # basemap.at terrain serves native raster tiles only to z17; MapLibre overzooms beyond.
    assert_equal 17, style.dig("sources", "basemap-at-gelaende", "maxzoom")

    basemap_layers = style.fetch("layers").select do |layer|
      layer["source-layer"].present? && layer["source"] != "austrian-rocks"
    end
    assert basemap_layers.any?, "expected basemap.at vector layers"
    assert_empty basemap_layers.reject { |layer| [ "basemap-at", "basemap-at-hoehenlinien" ].include?(layer["source"]) }
  end

  def assert_bergwerk_basemap_style_metadata(style)
    vector_layers = style.fetch("layers").select { |layer| layer["source"] == "basemap-at" }
    terrain_layers = style.fetch("layers").select { |layer| layer["source"] == "basemap-at-gelaende" }

    assert_equal 16, style.dig("sources", "basemap-at", "maxzoom")
    assert_equal 17, style.dig("sources", "basemap-at-gelaende", "maxzoom")
    assert vector_layers.any? { |layer| layer["minzoom"] == 16 }, "expected Bergwerk basemap style layers to include z16 vector detail"
    assert vector_layers.any? { |layer| layer["maxzoom"].nil? }, "expected top-end Bergwerk basemap vector layers to remain visible while the source overzooms"
    assert_empty vector_layers.select { |layer| layer["maxzoom"] == 20 }
    assert_empty vector_layers.select { |layer| layer["maxzoom"] == 24 }
    assert_equal 1, terrain_layers.size
    assert_equal 0, terrain_layers.first["minzoom"]
    assert_nil terrain_layers.first["maxzoom"]
  end

  def assert_basemap_at_contours(style, style_name)
    source = style.fetch("sources").fetch("basemap-at-hoehenlinien")

    assert_nil source["url"], "basemap.at contour source must not depend on a runtime TileJSON request"
    assert_equal [ "https://mapsneu.wien.gv.at/basemapv/bmapvhl/3857/tile/{z}/{y}/{x}.pbf" ], source.fetch("tiles")
    assert_equal 0, source.fetch("minzoom")
    assert_equal 16, source.fetch("maxzoom")
    assert_equal [ 8.8587, 45.7823, 17.1608, 49.5752 ], source.fetch("bounds")
    assert_equal "xyz", source.fetch("scheme")

    contour_layers = style.fetch("layers").select { |layer| layer["source"] == "basemap-at-hoehenlinien" }
    assert_equal 26, contour_layers.size
    assert contour_layers.any? do |layer|
      layer["source-layer"] == "AUSTRIA_HL_Gesamt_gen20cm_smooth20m_HL" && layer["minzoom"] == 17
    end
    assert contour_layers.any? do |layer|
      layer["source-layer"] == "AUSTRIA_HL50_100_1000_smooth500m_HL" && layer["minzoom"] == 10
    end
    assert contour_layers.any? do |layer|
      layer["type"] == "symbol" && layer.dig("layout", "text-font") == [ "Roboto-MediumItalic" ]
    end
    assert_empty contour_layers.reject { |layer| layer.fetch("id").start_with?("basemap-at-hoehenlinien-") }

    line_layers = contour_layers.select { |layer| layer["type"] == "line" }
    label_layers = contour_layers.select { |layer| layer["type"] == "symbol" }
    assert_equal 18, line_layers.size
    assert_equal 8, label_layers.size
    assert_empty line_layers.reject { |layer| layer.dig("paint", "line-opacity") == @configuration.contour_opacity }
    assert_empty label_layers.reject { |layer| layer.dig("paint", "text-opacity") == @configuration.contour_opacity }
    assert_empty line_layers.select { |layer| layer.dig("paint", "line-color").to_s.start_with?("rgba") }

    if style_name == "dark"
      assert contour_layers.any? do |layer|
        layer.dig("paint", "text-halo-color") == "rgba(15,23,42,0.75)"
      end
    else
      assert contour_layers.any? { |layer| layer.dig("paint", "line-color") == "rgb(128,102,89)" }
    end

    first_contour_line_index = style.fetch("layers").index do |layer|
      layer["source"] == "basemap-at-hoehenlinien" && layer["type"] == "line"
    end
    first_basemap_symbol_index = style.fetch("layers").index do |layer|
      layer["source"] == "basemap-at" && layer["type"] == "symbol"
    end
    first_austrian_rocks_index = style.fetch("layers").index { |layer| layer["source"] == "austrian-rocks" }
    last_contour_index = style.fetch("layers").rindex { |layer| layer["source"] == "basemap-at-hoehenlinien" }

    assert_operator first_contour_line_index, :<, first_basemap_symbol_index
    assert_operator last_contour_index, :<, first_austrian_rocks_index
  end

  def assert_no_mapbox_urls(style)
    assert_not_includes JSON.generate(style), "mapbox:" + "//"
  end

  def assert_required_basemap_at_attribution(style)
    attributions = style.fetch("sources").values.filter_map { |source| source["attribution"] if source.is_a?(Hash) }

    assert attributions.any? { |attribution| attribution.include?("Grundkarte:") && attribution.include?("https://basemap.at/") }, "missing linked basemap.at attribution"
  end

  def assert_no_open_street_map_attribution(style)
    attribution = style.fetch("sources").values.filter_map { |source| source["attribution"] if source.is_a?(Hash) }.join(" ")

    assert_no_match(/OpenStreetMap|\bOSM\b/, attribution)
  end

  def assert_terrain_opacity(style)
    terrain_layer = style.fetch("layers").find { |layer| layer.fetch("id").casecmp("gelände").zero? }

    assert_not_nil terrain_layer
    assert_equal @configuration.terrain_opacity, terrain_layer.dig("paint", "raster-opacity")
  end

  def assert_austrian_rocks_overlay_zoom_hierarchy(style)
    overlay_layers = style.fetch("layers").select { |layer| layer["source"] == "austrian-rocks" }

    assert_equal 13, overlay_layers.size
    assert_equal %w[
      region-hulls
      cluster-hulls
      areas-hulls
      areas-hulls-outline
      boulders
      boulders-outline
      walking-paths
      problems
      pois
      areas
      clusters
      regions
      boulders-texts
    ], overlay_layers.map { |layer| layer.fetch("id") }
    assert_equal "symbol", overlay_layer(style, "regions").fetch("type")
    assert_equal 9.5, overlay_layer(style, "regions").fetch("maxzoom")
    assert_equal [ "interpolate", [ "linear" ], [ "zoom" ], 9, 1, 9.5, 0 ], overlay_layer(style, "regions").dig("paint", "text-opacity")
    assert_equal 0, overlay_layer(style, "region-hulls").dig("paint", "fill-opacity")
    assert_equal 9.5, overlay_layer(style, "region-hulls").fetch("maxzoom")

    assert_equal "symbol", overlay_layer(style, "clusters").fetch("type")
    assert_equal 9, overlay_layer(style, "clusters").fetch("minzoom")
    assert_equal 12, overlay_layer(style, "clusters").fetch("maxzoom")
    assert_equal [ "interpolate", [ "linear" ], [ "zoom" ], 11.5, 1, 12, 0 ], overlay_layer(style, "clusters").dig("paint", "text-opacity")
    assert_equal 0, overlay_layer(style, "cluster-hulls").dig("paint", "fill-opacity")
    assert_equal 9, overlay_layer(style, "cluster-hulls").fetch("minzoom")
    assert_equal 12, overlay_layer(style, "cluster-hulls").fetch("maxzoom")

    assert_equal "symbol", overlay_layer(style, "areas").fetch("type")
    assert_equal 12, overlay_layer(style, "areas").fetch("minzoom")
    assert_equal 16, overlay_layer(style, "areas").fetch("maxzoom")
    assert_equal [ "interpolate", [ "linear" ], [ "zoom" ], 15.5, 1, 16, 0 ], overlay_layer(style, "areas").dig("paint", "text-opacity")
    assert_equal 11, overlay_layer(style, "areas-hulls").fetch("minzoom")
    assert_equal 16, overlay_layer(style, "areas-hulls").fetch("maxzoom")
    assert_equal [ "interpolate", [ "linear" ], [ "zoom" ], 0, 1, 15, 1, 16, 0 ], overlay_layer(style, "areas-hulls").dig("paint", "fill-opacity")
    assert_equal 11, overlay_layer(style, "areas-hulls-outline").fetch("minzoom")
    assert_equal 16, overlay_layer(style, "areas-hulls-outline").fetch("maxzoom")
    assert_equal [ "interpolate", [ "linear" ], [ "zoom" ], 0, 1, 15, 1, 16, 0 ], overlay_layer(style, "areas-hulls-outline").dig("paint", "line-opacity")
    assert_equal [ "interpolate", [ "linear" ], [ "zoom" ], 10, 5, 15, 5, 16, 0 ], overlay_layer(style, "areas-hulls-outline").dig("paint", "line-width")

    assert_equal "fill", overlay_layer(style, "boulders").fetch("type")
    assert_equal 14, overlay_layer(style, "boulders").fetch("minzoom")
    assert_equal 13, overlay_layer(style, "boulders-outline").fetch("minzoom")
    assert_equal "symbol", overlay_layer(style, "boulders-texts").fetch("type")
    assert_equal 18, overlay_layer(style, "boulders-texts").fetch("minzoom")
    assert_equal [ "interpolate", [ "linear" ], [ "zoom" ], 18, 0, 18.5, 1, 22, 1 ], overlay_layer(style, "boulders-texts").dig("paint", "text-opacity")
    assert_equal 14, overlay_layer(style, "walking-paths").fetch("minzoom")
    assert_equal [ "interpolate", [ "linear" ], [ "zoom" ], 14, 0, 15, 1 ], overlay_layer(style, "walking-paths").dig("paint", "line-opacity")
    assert_equal "symbol", overlay_layer(style, "pois").fetch("type")
    assert_equal 11, overlay_layer(style, "pois").fetch("minzoom")
    assert_empty overlay_layers.select { |layer| layer["type"] == "symbol" && layer.dig("layout", "text-font").blank? }
    assert_equal [ "Roboto-Regular" ], overlay_layer(style, "areas").dig("layout", "text-font")
    assert_equal [ "Roboto-Regular" ], overlay_layer(style, "boulders-texts").dig("layout", "text-font")
    assert_equal 15, overlay_layer(style, "problems").fetch("minzoom")
    assert_equal [ "interpolate", [ "linear" ], [ "zoom" ], 15, 2, 18, 4, 22, 10 ], overlay_layer(style, "problems").dig("paint", "circle-radius")
    assert_equal "#878A8D", overlay_layer(style, "problems").dig("paint", "circle-color")
    assert_equal [ "interpolate", [ "linear" ], [ "zoom" ], 14.5, 0, 15, 1 ], overlay_layer(style, "problems").dig("paint", "circle-opacity")
    assert_nil overlay_layer(style, "problems").dig("paint", "circle-stroke-color")
    assert_nil style.fetch("layers").find { |layer| layer["source"] == "austrian-rocks" && layer["id"] == "problems-texts" }
  end

  def overlay_layer(style, layer_id)
    style.fetch("layers").find { |layer| layer["source"] == "austrian-rocks" && layer["id"] == layer_id } || flunk("missing Austrian Rocks layer #{layer_id}")
  end

  def assert_all_layer_contract_source_layers_are_styled(style)
    styled_source_layers = style.fetch("layers").filter_map do |layer|
      layer["source-layer"] if layer["source"] == "austrian-rocks"
    end.uniq

    assert_empty MapTiles::LayerContract.layer_names - styled_source_layers
  end

  def map_tile_settings
    {
      "artifact_basename" => "austrian-rocks",
      "output_dir" => @output_dir.to_s,
      "public_cdn_host" => "https://cdn.example.test",
      "bunny_prefix" => "map_tiles/test",
      "style_prefix" => "map_styles",
      "manifest_prefix" => "map_tiles",
      "manifest_object_name" => "current.json",
      "default_style" => "light",
      "basemap_at_style_url" => "https://basemap.bergwerk-gis.at/api/styles/basemap-at-farbe",
      "basemap_at_attribution" => "Grundkarte: <a href=\"https://basemap.at/\" target=\"_blank\" rel=\"noopener noreferrer\">basemap.at</a>",
      "terrain_opacity" => 0.35,
      "contour_opacity" => 0.35,
      "optional_production_layers" => []
    }
  end

  class FakeTemplateConfiguration
    def initialize(configuration, template_dir)
      @configuration = configuration
      @template_dir = template_dir
    end

    def style_template_path(style_name)
      @template_dir.join("austrian_rocks_#{style_name}.json")
    end

    def method_missing(method_name, *arguments, &block)
      if @configuration.respond_to?(method_name)
        @configuration.public_send(method_name, *arguments, &block)
      else
        super
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      @configuration.respond_to?(method_name, include_private) || super
    end
  end
end
