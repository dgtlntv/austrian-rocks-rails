# frozen_string_literal: true

require "test_helper"
require "securerandom"
require "map_tiles/configuration"

class MapTiles::ConfigurationTest < ActiveSupport::TestCase
  setup do
    @output_dir = "tmp/configuration_test/#{SecureRandom.hex(8)}"
  end

  test "loads committed Rails map tile configuration for test" do
    configuration = MapTiles::Configuration.new(version: "2026-06-07")

    assert_equal Rails.root.join("tmp/map_tiles"), configuration.output_dir
    assert_equal Rails.root.join("tmp/map_tiles/geojson"), configuration.geojson_dir
    assert_equal "austrian-rocks", configuration.artifact_basename
    assert_equal "tiles.austrian.rocks", configuration.public_cdn_host
    assert_equal "map_tiles/test", configuration.bunny_prefix
    assert_equal [], configuration.optional_production_layers
    assert_equal 30.minutes, configuration.automatic_publish_debounce
    assert_equal 60, configuration.manifest_cache_ttl_seconds
    assert_equal "public, max-age=31536000, immutable", configuration.pmtiles_cache_control
    assert_equal "application/json", configuration.manifest_content_type
  end

  test "supports environment-specific settings through injected Rails config" do
    development = MapTiles::Configuration.new(
      version: "2026-06-07",
      settings: settings("bunny_prefix" => "map_tiles/e2e", "optional_production_layers" => [ "pois" ])
    )
    test = MapTiles::Configuration.new(version: "2026-06-07", settings: settings("bunny_prefix" => "map_tiles/test"))
    production = MapTiles::Configuration.new(
      version: "2026-06-07",
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
    configuration = MapTiles::Configuration.new(version: "2026-06-07", settings: development_settings)

    assert_equal "map_tiles/e2e", configuration.bunny_prefix
    assert_equal [ "pois" ], configuration.optional_production_layers
  end

  test "uses explicit safe version for artifact paths and object keys" do
    configuration = MapTiles::Configuration.new(version: "2026.06_07-e2e", settings: settings("bunny_prefix" => "/maps/e2e/"))

    assert_equal "2026.06_07-e2e", configuration.version
    assert_equal Rails.root.join("#{@output_dir}/austrian-rocks-2026.06_07-e2e.pmtiles"), configuration.artifact_path
    assert_equal Rails.root.join("#{@output_dir}/austrian-rocks-2026.06_07-e2e.metadata.json"), configuration.metadata_path
    assert_equal "maps/e2e/austrian-rocks-2026.06_07-e2e.pmtiles", configuration.versioned_object_key
    assert_not_respond_to configuration, :latest_object_key
  end

  test "requires explicit version for artifact-specific methods only" do
    configuration = MapTiles::Configuration.new(settings: settings)

    assert_equal Rails.root.join(@output_dir), configuration.output_dir
    assert_equal Rails.root.join("#{@output_dir}/geojson"), configuration.geojson_dir

    error = assert_raises(ArgumentError) { configuration.artifact_path }
    assert_equal "--version is required for build, smoke, and publish", error.message
  end

  test "rejects unsafe configured path segments and versions" do
    assert_raises(ArgumentError) do
      MapTiles::Configuration.new(version: "2026/06/07", settings: settings).artifact_path
    end

    assert_raises(ArgumentError) do
      MapTiles::Configuration.new(version: "2026-06-07", settings: settings("artifact_basename" => "../evil")).artifact_path
    end

    assert_raises(ArgumentError) do
      MapTiles::Configuration.new(version: "2026-06-07", settings: settings("bunny_prefix" => "maps/../evil")).versioned_object_key
    end
  end

  test "rejects unknown optional production layer names" do
    configuration = MapTiles::Configuration.new(
      version: "2026-06-07",
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

  test "exposes automatic publish debounce duration" do
    configuration = MapTiles::Configuration.new(settings: settings("automatic_publish_debounce_minutes" => "45"))

    assert_equal 45.minutes, configuration.automatic_publish_debounce
  end

  test "exposes manifest cache TTL" do
    configuration = MapTiles::Configuration.new(settings: settings("manifest_cache_ttl_seconds" => "120"))

    assert_equal 120, configuration.manifest_cache_ttl_seconds
  end

  test "exposes PMTiles cache control header" do
    configuration = MapTiles::Configuration.new(
      settings: settings("pmtiles_cache_control" => "public, max-age=86400")
    )

    assert_equal "public, max-age=86400", configuration.pmtiles_cache_control
  end

  test "exposes manifest content type" do
    configuration = MapTiles::Configuration.new(
      settings: settings("manifest_content_type" => "application/vnd.custom+json")
    )

    assert_equal "application/vnd.custom+json", configuration.manifest_content_type
  end

  test "returns latest manifest object key derived from basename and prefix" do
    configuration = MapTiles::Configuration.new(version: "v1", settings: settings("bunny_prefix" => "maps/prod"))

    assert_equal "maps/prod/austrian-rocks-latest.json", configuration.latest_manifest_object_key
  end

  test "returns latest manifest basename" do
    configuration = MapTiles::Configuration.new(version: "v1", settings: settings)

    assert_equal "austrian-rocks-latest.json", configuration.latest_manifest_basename
  end

  test "does not expose latest.pmtiles via manifest method" do
    configuration = MapTiles::Configuration.new(version: "v1", settings: settings)

    assert_equal "austrian-rocks-latest.json", configuration.latest_manifest_basename
    assert_not_respond_to configuration, :latest_manifest_pmtiles
  end

  private

  def settings(overrides = {})
    {
      "artifact_basename" => "austrian-rocks",
      "output_dir" => @output_dir,
      "public_cdn_host" => "https://cdn.example.test",
      "bunny_prefix" => "maps",
      "optional_production_layers" => [],
      "automatic_publish_debounce_minutes" => "30",
      "manifest_cache_ttl_seconds" => "60",
      "pmtiles_cache_control" => "public, max-age=31536000, immutable",
      "manifest_content_type" => "application/json"
    }.merge(overrides)
  end
end
