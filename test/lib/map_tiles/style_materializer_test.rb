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
      assert_no_mapbox_urls(style)
      assert_required_basemap_at_attribution(style)
      assert_no_open_street_map_attribution(style)
      assert_terrain_opacity(style)
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
      assert_no_mapbox_urls(materialized)
      assert_required_basemap_at_attribution(materialized)
      assert_no_open_street_map_attribution(materialized)
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

  def assert_no_mapbox_urls(style)
    assert_not_includes JSON.generate(style), "mapbox://"
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
      "basemap_at_style_url" => "https://mapsneu.wien.gv.at/basemapvectorneu/root.json",
      "basemap_at_attribution" => "Grundkarte: <a href=\"https://basemap.at/\" target=\"_blank\" rel=\"noopener noreferrer\">basemap.at</a>",
      "terrain_opacity" => 0.35,
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
