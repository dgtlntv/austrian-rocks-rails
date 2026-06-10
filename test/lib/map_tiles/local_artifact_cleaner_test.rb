# frozen_string_literal: true

require "test_helper"
require "securerandom"
require "stringio"
require "map_tiles/local_artifact_cleaner"

class MapTiles::LocalArtifactCleanerTest < ActiveSupport::TestCase
  setup do
    @output_dir = Rails.root.join("tmp/local_artifact_cleaner_test/#{SecureRandom.hex(8)}")
    @configuration = MapTiles::Configuration.new(version: "current", settings: map_tile_settings)
    FileUtils.mkdir_p(@configuration.output_dir)
  end

  teardown do
    FileUtils.rm_rf(@configuration.output_dir)
  end

  test "removes old local map release artifacts while keeping current and fresh files" do
    old_pmtiles = write_artifact("austrian-rocks-old.pmtiles", days_old: 30)
    old_metadata = write_artifact("austrian-rocks-old.metadata.json", days_old: 30)
    old_light_style = write_artifact("austrian-rocks-old-light.json", days_old: 30)
    old_dark_style = write_artifact("austrian-rocks-old-dark.json", days_old: 30)
    old_sprite_sheet = write_artifact("austrian-rocks-old-sprite.png", days_old: 30)
    old_sprite_index = write_artifact("austrian-rocks-old-sprite.json", days_old: 30)
    old_sprite_sheet_retina = write_artifact("austrian-rocks-old-sprite@2x.png", days_old: 30)
    old_sprite_index_retina = write_artifact("austrian-rocks-old-sprite@2x.json", days_old: 30)
    fresh_pmtiles = write_artifact("austrian-rocks-fresh.pmtiles", days_old: 1)
    fresh_light_style = write_artifact("austrian-rocks-fresh-light.json", days_old: 1)
    current_pmtiles = write_artifact("austrian-rocks-current.pmtiles", days_old: 30)
    current_metadata = write_artifact("austrian-rocks-current.metadata.json", days_old: 30)
    current_light_style = write_artifact("austrian-rocks-current-light.json", days_old: 30)
    current_dark_style = write_artifact("austrian-rocks-current-dark.json", days_old: 30)
    current_sprite_sheet = write_artifact("austrian-rocks-current-sprite.png", days_old: 30)
    current_sprite_index = write_artifact("austrian-rocks-current-sprite@2x.json", days_old: 30)
    current_manifest = write_artifact("current.json", days_old: 30)
    unrelated = write_artifact("other-old.pmtiles", days_old: 30)
    geojson = write_artifact("geojson/problems.geojson", days_old: 30)
    out = StringIO.new

    removed = MapTiles::LocalArtifactCleaner.new(configuration: @configuration, retention_days: 14, out: out).clean

    expected_removed = [
      old_dark_style, old_light_style, old_metadata, old_pmtiles,
      old_sprite_sheet, old_sprite_index, old_sprite_sheet_retina, old_sprite_index_retina
    ]
    assert_equal expected_removed.map(&:to_s).sort, removed.map(&:to_s).sort
    expected_removed.each { |path| assert_not_predicate path, :exist? }
    assert_predicate fresh_pmtiles, :exist?
    assert_predicate fresh_light_style, :exist?
    assert_predicate current_pmtiles, :exist?
    assert_predicate current_metadata, :exist?
    assert_predicate current_light_style, :exist?
    assert_predicate current_dark_style, :exist?
    assert_predicate current_sprite_sheet, :exist?
    assert_predicate current_sprite_index, :exist?
    assert_predicate current_manifest, :exist?
    assert_predicate unrelated, :exist?
    assert_predicate geojson, :exist?
    assert_includes out.string, "cleaned 8 old local map release artifact(s)"
  end

  private

  def write_artifact(relative_path, days_old:)
    path = @configuration.output_dir.join(relative_path)
    FileUtils.mkdir_p(path.dirname)
    path.write("artifact")
    FileUtils.touch(path, mtime: (Time.current - days_old.days).to_time)
    path
  end

  def map_tile_settings
    {
      "artifact_basename" => "austrian-rocks",
      "output_dir" => @output_dir.to_s,
      "public_cdn_host" => "https://cdn.example.test",
      "bunny_prefix" => "maps",
      "style_prefix" => "map_styles",
      "manifest_prefix" => "map_tiles",
      "manifest_object_name" => "current.json",
      "default_style" => "light",
      "basemap_at_style_url" => "https://basemap.bergwerk-gis.at/api/styles/basemap-at-farbe",
      "basemap_at_attribution" => "Grundkarte: <a href=\"https://basemap.at/\" target=\"_blank\" rel=\"noopener noreferrer\">basemap.at</a>",
      "terrain_opacity" => 0.35,
      "optional_production_layers" => []
    }
  end
end
