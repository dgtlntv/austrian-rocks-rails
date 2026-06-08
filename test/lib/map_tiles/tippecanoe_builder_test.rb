# frozen_string_literal: true

require "test_helper"
require "securerandom"
require "map_tiles/layer_contract"
require "map_tiles/configuration"
require "map_tiles/tippecanoe_builder"

class MapTiles::TippecanoeBuilderTest < ActiveSupport::TestCase
  setup do
    @output_dir = Rails.root.join("tmp/tippecanoe_builder_test/#{SecureRandom.hex(8)}")
    @configuration = MapTiles::Configuration.new(version: "2026-06-07", settings: map_tile_settings)
    @layer_paths = MapTiles::LayerContract.layer_names.to_h do |layer_name|
      [ layer_name, Rails.root.join("tmp/geojson/#{layer_name}.geojson") ]
    end
  end

  teardown do
    FileUtils.rm_rf(@configuration.output_dir)
  end

  test "raises clear install guidance when Tippecanoe is missing" do
    builder = MapTiles::TippecanoeBuilder.new(
      configuration: @configuration,
      executable_checker: ->(_binary) { false },
      command_runner: ->(_command) { flunk "command should not run when executable is missing" }
    )

    error = assert_raises(MapTiles::TippecanoeBuilder::MissingExecutableError) do
      builder.build(layer_paths: @layer_paths)
    end

    assert_includes error.message, "Tippecanoe is required"
    assert_includes error.message, "brew install tippecanoe"
  end

  test "constructs a named-layer PMTiles build command without invoking the binary in tests" do
    captured_command = nil
    builder = MapTiles::TippecanoeBuilder.new(
      configuration: @configuration,
      executable_checker: ->(_binary) { true },
      command_runner: ->(command) { captured_command = command; true }
    )

    artifact_path = builder.build(layer_paths: @layer_paths)

    assert_equal @configuration.artifact_path, artifact_path
    assert_equal "tippecanoe", captured_command.first
    assert_includes captured_command, "--force"
    assert_includes captured_command, "--minimum-zoom=0"
    assert_includes captured_command, "--maximum-zoom=16"
    assert_includes captured_command, "--output=#{@configuration.artifact_path}"
    assert_not captured_command.any? { |part| part.include?("output-to-directory") }

    MapTiles::LayerContract.layer_names.each do |layer_name|
      assert_includes captured_command, "--named-layer=#{layer_name}:#{@layer_paths.fetch(layer_name)}"
    end
  end

  test "fails when a required layer path is missing" do
    builder = MapTiles::TippecanoeBuilder.new(
      configuration: @configuration,
      executable_checker: ->(_binary) { true }
    )

    assert_raises(KeyError) do
      builder.build_command(layer_paths: @layer_paths.except("pois"))
    end
  end

  private

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
