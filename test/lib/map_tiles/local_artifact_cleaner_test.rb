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

  test "removes old local PMTiles artifacts while keeping current and fresh files" do
    old_pmtiles = write_artifact("austrian-rocks-old.pmtiles", days_old: 30)
    old_metadata = write_artifact("austrian-rocks-old.metadata.json", days_old: 30)
    fresh_pmtiles = write_artifact("austrian-rocks-fresh.pmtiles", days_old: 1)
    current_pmtiles = write_artifact("austrian-rocks-current.pmtiles", days_old: 30)
    current_metadata = write_artifact("austrian-rocks-current.metadata.json", days_old: 30)
    unrelated = write_artifact("other-old.pmtiles", days_old: 30)
    geojson = write_artifact("geojson/problems.geojson", days_old: 30)
    out = StringIO.new

    removed = MapTiles::LocalArtifactCleaner.new(configuration: @configuration, retention_days: 14, out: out).clean

    assert_equal [ old_metadata, old_pmtiles ].map(&:to_s).sort, removed.map(&:to_s).sort
    assert_not_predicate old_pmtiles, :exist?
    assert_not_predicate old_metadata, :exist?
    assert_predicate fresh_pmtiles, :exist?
    assert_predicate current_pmtiles, :exist?
    assert_predicate current_metadata, :exist?
    assert_predicate unrelated, :exist?
    assert_predicate geojson, :exist?
    assert_includes out.string, "cleaned 2 old local PMTiles artifact(s)"
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
      "optional_production_layers" => []
    }
  end
end
