# frozen_string_literal: true

require "test_helper"
require "securerandom"
require "json"
require "map_tiles/release_manifest"

class MapTiles::ReleaseManifestTest < ActiveSupport::TestCase
  setup do
    @output_dir = Rails.root.join("tmp/release_manifest_test/#{SecureRandom.hex(8)}")
    @configuration = MapTiles::Configuration.new(version: "2026-06-09", settings: map_tile_settings)
  end

  teardown do
    FileUtils.rm_rf(@output_dir)
  end

  test "writes current release manifest with versioned PMTiles and style urls" do
    clock = -> { Time.utc(2026, 6, 9, 12, 30, 45) }

    path = MapTiles::ReleaseManifest.new(configuration: @configuration, clock: clock).write

    assert_equal @configuration.manifest_artifact_path, path
    manifest = JSON.parse(path.read)
    assert_equal "2026-06-09", manifest.fetch("version")
    assert_equal "https://cdn.example.test/map_tiles/austrian-rocks-2026-06-09.pmtiles", manifest.fetch("pmtilesUrl")
    assert_equal(
      {
        "light" => "https://cdn.example.test/map_styles/austrian-rocks-2026-06-09-light.json",
        "dark" => "https://cdn.example.test/map_styles/austrian-rocks-2026-06-09-dark.json"
      },
      manifest.fetch("styles")
    )
    assert_equal "2026-06-09T12:30:45Z", manifest.fetch("publishedAt")
  end

  test "rejects unsafe versions and public urls" do
    unsafe_version = MapTiles::Configuration.new(version: "2026/06/09", settings: map_tile_settings)

    assert_raises(MapTiles::ReleaseManifest::Error) do
      MapTiles::ReleaseManifest.new(configuration: unsafe_version).write
    end

    credentialed_url = MapTiles::Configuration.new(
      version: "2026-06-09",
      settings: map_tile_settings("public_cdn_host" => "https://user:pass@cdn.example.test")
    )

    error = assert_raises(MapTiles::ReleaseManifest::Error) do
      MapTiles::ReleaseManifest.new(configuration: credentialed_url).write
    end
    assert_includes error.message, "credentials"
    assert_not_includes error.message, "pass"
  end

  test "manifest does not contain Bunny credentials" do
    secret_env = {
      "BUNNY_STORAGE_ACCESS_KEY_ID" => "key-id",
      "BUNNY_STORAGE_SECRET_ACCESS_KEY" => "super-secret"
    }
    configuration = MapTiles::Configuration.new(version: "2026-06-09", env: secret_env, settings: map_tile_settings)

    path = MapTiles::ReleaseManifest.new(configuration: configuration).write

    assert_not_includes path.read, "key-id"
    assert_not_includes path.read, "super-secret"
  end

  private

  def map_tile_settings(overrides = {})
    {
      "artifact_basename" => "austrian-rocks",
      "output_dir" => @output_dir.to_s,
      "public_cdn_host" => "https://cdn.example.test",
      "bunny_prefix" => "map_tiles",
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
