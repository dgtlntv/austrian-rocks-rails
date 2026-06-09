# frozen_string_literal: true

require "test_helper"
require "securerandom"
require "map_tiles/configuration"

class MapTiles::ConfigurationTest < ActiveSupport::TestCase
  setup do
    @output_dir = "tmp/configuration_test/#{SecureRandom.hex(8)}"
  end

  test "loads committed Rails map tile configuration for test" do
    configuration = MapTiles::Configuration.new(version: "2026-06-09")

    assert_equal Rails.root.join("tmp/map_tiles"), configuration.output_dir
    assert_equal Rails.root.join("tmp/map_tiles/geojson"), configuration.geojson_dir
    assert_equal "austrian-rocks", configuration.artifact_basename
    assert_equal "tiles.austrian.rocks", configuration.public_cdn_host
    assert_equal "map_tiles/test", configuration.bunny_prefix
    assert_equal "map_styles", configuration.style_prefix
    assert_equal "map_tiles", configuration.manifest_prefix
    assert_equal "current.json", configuration.manifest_object_name
    assert_equal "light", configuration.default_style
    assert_equal "https://mapsneu.wien.gv.at/basemapvectorneu/root.json", configuration.basemap_at_style_url
    assert_includes configuration.basemap_at_attribution, "Grundkarte:"
    assert_includes configuration.basemap_at_attribution, "https://basemap.at/"
    assert_equal 0.35, configuration.terrain_opacity
    assert_equal [], configuration.optional_production_layers
  end

  test "supports environment-specific settings through injected Rails config" do
    development = MapTiles::Configuration.new(
      version: "2026-06-09",
      settings: settings("bunny_prefix" => "map_tiles/e2e", "optional_production_layers" => [ "pois" ])
    )
    test = MapTiles::Configuration.new(version: "2026-06-09", settings: settings("bunny_prefix" => "map_tiles/test"))
    production = MapTiles::Configuration.new(
      version: "2026-06-09",
      settings: settings("bunny_prefix" => "map_tiles", "optional_production_layers" => [ "pois" ])
    )

    assert_equal "map_tiles/e2e", development.bunny_prefix
    assert_equal [ "pois" ], development.optional_production_layers
    assert_equal "map_tiles/test", test.bunny_prefix
    assert_equal "map_tiles", production.bunny_prefix
    assert_equal [ "pois" ], production.optional_production_layers
  end

  test "committed development config supports zero-POI local E2E smoke" do
    development_settings = Rails.application.config_for(:map_tiles, env: "development")
    configuration = MapTiles::Configuration.new(version: "2026-06-09", settings: development_settings)

    assert_equal "map_tiles/e2e", configuration.bunny_prefix
    assert_equal [ "pois" ], configuration.optional_production_layers
  end

  test "uses explicit safe version for artifact paths object keys and public urls" do
    configuration = MapTiles::Configuration.new(version: "2026-06-09", settings: settings("bunny_prefix" => "/map_tiles/test/"))

    assert_equal "2026-06-09", configuration.version
    assert_equal Rails.root.join("#{@output_dir}/austrian-rocks-2026-06-09.pmtiles"), configuration.artifact_path
    assert_equal Rails.root.join("#{@output_dir}/austrian-rocks-2026-06-09.metadata.json"), configuration.metadata_path
    assert_equal Rails.root.join("#{@output_dir}/austrian-rocks-2026-06-09-light.json"), configuration.style_artifact_path("light")
    assert_equal Rails.root.join("#{@output_dir}/current.json"), configuration.manifest_artifact_path
    assert_equal Rails.root.join("config/map_styles/austrian_rocks_light.json"), configuration.style_template_path("light")
    assert_equal "map_tiles/test/austrian-rocks-2026-06-09.pmtiles", configuration.versioned_object_key
    assert_equal "map_styles/austrian-rocks-2026-06-09-light.json", configuration.style_object_key("light")
    assert_equal "map_styles/austrian-rocks-2026-06-09-dark.json", configuration.style_object_key("dark")
    assert_equal "map_tiles/current.json", configuration.manifest_object_key
    assert_equal "https://cdn.example.test/map_tiles/test/austrian-rocks-2026-06-09.pmtiles", configuration.pmtiles_public_url
    assert_equal "https://cdn.example.test/map_styles/austrian-rocks-2026-06-09-light.json", configuration.style_public_url("light")
    assert_equal "https://cdn.example.test/map_tiles/current.json", configuration.manifest_public_url
  end

  test "requires explicit version for artifact-specific methods only" do
    configuration = MapTiles::Configuration.new(settings: settings)

    assert_equal Rails.root.join(@output_dir), configuration.output_dir
    assert_equal Rails.root.join("#{@output_dir}/geojson"), configuration.geojson_dir
    assert_equal "https://cdn.example.test/map_tiles/current.json", configuration.manifest_public_url

    error = assert_raises(ArgumentError) { configuration.artifact_path }
    assert_equal "--version is required for build, smoke, and publish", error.message
  end

  test "rejects unsafe configured path segments and versions" do
    assert_raises(ArgumentError) do
      MapTiles::Configuration.new(version: "2026/06/09", settings: settings).artifact_path
    end

    assert_raises(ArgumentError) do
      MapTiles::Configuration.new(version: "2026-06-09", settings: settings("artifact_basename" => "../evil")).artifact_path
    end

    assert_raises(ArgumentError) do
      MapTiles::Configuration.new(version: "2026-06-09", settings: settings("bunny_prefix" => "maps/../evil")).versioned_object_key
    end

    assert_raises(ArgumentError) do
      MapTiles::Configuration.new(version: "2026-06-09", settings: settings("style_prefix" => "../styles")).style_object_key("light")
    end

    assert_raises(ArgumentError) do
      MapTiles::Configuration.new(version: "2026-06-09", settings: settings("manifest_object_name" => "current.txt")).manifest_object_key
    end
  end

  test "rejects unsafe style names public hosts and object keys" do
    configuration = MapTiles::Configuration.new(version: "2026-06-09", settings: settings)

    assert_raises(ArgumentError) { configuration.style_object_key("blue") }
    assert_raises(ArgumentError) { configuration.public_url_for_object_key("") }
    assert_raises(ArgumentError) { configuration.public_url_for_object_key("/map_tiles/austrian-rocks.pmtiles") }
    assert_raises(ArgumentError) { configuration.public_url_for_object_key("map_tiles/austrian-rocks.pmtiles/") }
    assert_raises(ArgumentError) { configuration.public_url_for_object_key("map_tiles//austrian-rocks.pmtiles") }
    assert_raises(ArgumentError) { configuration.public_url_for_object_key("map_tiles/../evil.pmtiles") }
    assert_raises(ArgumentError) do
      MapTiles::Configuration.new(version: "2026-06-09", settings: settings("public_cdn_host" => "http://cdn.example.test")).pmtiles_public_url
    end
    assert_raises(ArgumentError) do
      MapTiles::Configuration.new(version: "2026-06-09", settings: settings("public_cdn_host" => "https://user:pass@cdn.example.test")).pmtiles_public_url
    end
    assert_raises(ArgumentError) do
      MapTiles::Configuration.new(version: "2026-06-09", settings: settings("public_cdn_host" => "https://cdn.example.test/maps")).pmtiles_public_url
    end
    assert_raises(ArgumentError) do
      MapTiles::Configuration.new(version: "2026-06-09", settings: settings("public_cdn_host" => "https://cdn.example.test?token=x")).pmtiles_public_url
    end
    assert_raises(ArgumentError) do
      MapTiles::Configuration.new(version: "2026-06-09", settings: settings("public_cdn_host" => "https://cdn.example.test#tiles")).pmtiles_public_url
    end
  end

  test "removes mutable PMTiles helper" do
    configuration = MapTiles::Configuration.new(version: "2026-06-09", settings: settings)

    assert_not_respond_to configuration, :"latest_#{'object'}_key"
  end

  test "rejects unknown optional production layer names" do
    configuration = MapTiles::Configuration.new(
      version: "2026-06-09",
      settings: settings("optional_production_layers" => [ "pois", "bogus_layer" ])
    )

    error = assert_raises(ArgumentError) { configuration.optional_production_layers }
    assert_includes error.message, "bogus_layer"
  end

  test "ignores legacy non-secret map tile environment overrides" do
    env = {
      "MAP_TILES_PUBLIC_CDN_HOST" => "https://legacy.example.test",
      "MAP_TILES_BUNNY_PREFIX" => "legacy_prefix",
      "MAP_TILES_OUTPUT_DIR" => "tmp/legacy_map_tiles",
      "MAP_TILES_VERSION" => "legacy-version"
    }
    configuration = MapTiles::Configuration.new(version: "explicit-version", env: env, settings: settings)

    assert_equal Rails.root.join(@output_dir), configuration.output_dir
    assert_equal "https://cdn.example.test", configuration.public_cdn_host
    assert_equal "maps", configuration.bunny_prefix
    assert_equal "explicit-version", configuration.version
  end

  private

  def settings(overrides = {})
    {
      "artifact_basename" => "austrian-rocks",
      "output_dir" => @output_dir,
      "public_cdn_host" => "https://cdn.example.test",
      "bunny_prefix" => "maps",
      "style_prefix" => "map_styles",
      "manifest_prefix" => "map_tiles",
      "manifest_object_name" => "current.json",
      "default_style" => "light",
      "basemap_at_style_url" => "https://mapsneu.wien.gv.at/basemapvectorneu/root.json",
      "basemap_at_attribution" => "Grundkarte: <a href=\"https://basemap.at/\" target=\"_blank\" rel=\"noopener noreferrer\">basemap.at</a>",
      "terrain_opacity" => 0.35,
      "optional_production_layers" => []
    }.merge(overrides)
  end
end
