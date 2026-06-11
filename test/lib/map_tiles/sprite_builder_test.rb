# frozen_string_literal: true

require "test_helper"
require "json"
require "securerandom"
require "tmpdir"
require "vips"
require "map_tiles/sprite_builder"

class MapTiles::SpriteBuilderTest < ActiveSupport::TestCase
  setup do
    @output_dir = Rails.root.join("tmp/sprite_builder_test/#{SecureRandom.hex(8)}")
    @configuration = MapTiles::Configuration.new(version: "2026-06-10", settings: map_tile_settings)
    @source_dir = Rails.root.join("config/map_styles/sprite")
  end

  teardown do
    FileUtils.rm_rf(@output_dir)
  end

  test "packs the committed icons into versioned sprite artifacts at both pixel ratios" do
    artifacts = MapTiles::SpriteBuilder.new(configuration: @configuration).build

    assert_equal %w[sprite.png sprite.json sprite@2x.png sprite@2x.json].sort, artifacts.keys.sort
    assert_equal @configuration.sprite_artifact_path(".png"), artifacts.fetch("sprite.png")
    assert_equal @configuration.sprite_artifact_path("@2x.json"), artifacts.fetch("sprite@2x.json")
    artifacts.each_value do |path|
      assert_predicate path, :exist?
      assert_predicate path.size, :positive?
    end

    committed_icon_names = @source_dir.glob("*.png").map { |path| path.basename(".png").to_s }.reject { |name| name.end_with?("@2x") }.sort
    assert_includes committed_icon_names, "ar-pin-region"
    assert_includes committed_icon_names, "ar-pin-region-selected"

    { 1 => "sprite.json", 2 => "sprite@2x.json" }.each do |ratio, json_name|
      index = JSON.parse(artifacts.fetch(json_name).read)
      assert_equal committed_icon_names, index.keys.sort
      index.each_value { |entry| assert_equal ratio, entry.fetch("pixelRatio") }
    end
  end

  test "sprite index rects are disjoint and inside the sheet" do
    artifacts = MapTiles::SpriteBuilder.new(configuration: @configuration).build

    { "sprite.json" => "sprite.png", "sprite@2x.json" => "sprite@2x.png" }.each do |json_name, png_name|
      sheet = Vips::Image.new_from_file(artifacts.fetch(png_name).to_s)
      entries = JSON.parse(artifacts.fetch(json_name).read).values

      entries.each do |entry|
        assert_equal 0, entry.fetch("y")
        assert_operator entry.fetch("x") + entry.fetch("width"), :<=, sheet.width
        assert_operator entry.fetch("height"), :<=, sheet.height
      end
      spans = entries.map { |entry| [ entry.fetch("x"), entry.fetch("x") + entry.fetch("width") ] }.sort
      spans.each_cons(2) do |(_, first_end), (second_start, _)|
        assert_operator first_end, :<=, second_start, "sprite rects overlap"
      end
      assert_equal sheet.width, entries.sum { |entry| entry.fetch("width") }
    end
  end

  test "2x icon rects are exactly double the 1x rects" do
    artifacts = MapTiles::SpriteBuilder.new(configuration: @configuration).build

    base = JSON.parse(artifacts.fetch("sprite.json").read)
    retina = JSON.parse(artifacts.fetch("sprite@2x.json").read)

    base.each do |name, entry|
      assert_equal entry.fetch("width") * 2, retina.fetch(name).fetch("width")
      assert_equal entry.fetch("height") * 2, retina.fetch(name).fetch("height")
    end
  end

  test "fails when an icon is missing its 2x counterpart" do
    Dir.mktmpdir("sprite-builder") do |dir|
      source_dir = Pathname(dir)
      FileUtils.cp(@source_dir.join("ar-pin-region.png"), source_dir.join("ar-pin-region.png"))

      error = assert_raises(MapTiles::SpriteBuilder::Error) do
        MapTiles::SpriteBuilder.new(configuration: @configuration, source_dir: source_dir).build
      end

      assert_includes error.message, "ar-pin-region"
      assert_includes error.message, "2x"
    end
  end

  test "fails when an icon is missing its 1x counterpart" do
    Dir.mktmpdir("sprite-builder") do |dir|
      source_dir = Pathname(dir)
      FileUtils.cp(@source_dir.join("ar-pin-region@2x.png"), source_dir.join("ar-pin-region@2x.png"))

      error = assert_raises(MapTiles::SpriteBuilder::Error) do
        MapTiles::SpriteBuilder.new(configuration: @configuration, source_dir: source_dir).build
      end

      assert_includes error.message, "ar-pin-region"
      assert_includes error.message, "1x"
    end
  end

  test "fails when the source directory has no icons" do
    Dir.mktmpdir("sprite-builder") do |dir|
      error = assert_raises(MapTiles::SpriteBuilder::Error) do
        MapTiles::SpriteBuilder.new(configuration: @configuration, source_dir: Pathname(dir)).build
      end

      assert_includes error.message, "no sprite icon PNGs"
    end
  end

  private

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
      "basemap_at_attribution" => "Grundkarte: basemap.at",
      "terrain_opacity" => 0.35,
      "contour_opacity" => 0.35,
      "optional_production_layers" => []
    }
  end
end
