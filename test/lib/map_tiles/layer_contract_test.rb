# frozen_string_literal: true

require "test_helper"
require "map_tiles/layer_contract"

class MapTiles::LayerContractTest < ActiveSupport::TestCase
  test "defines the expected source layers in contract order" do
    assert_equal %w[
      problems
      boulders
      areas
      area_hulls
      clusters
      cluster_hulls
      regions
      region_hulls
      walking_paths
      pois
    ], MapTiles::LayerContract.layer_names
  end

  test "sets native max zoom sixteen for the overlay" do
    assert_equal 16, MapTiles::LayerContract.native_max_zoom
  end

  test "uses camelCase feature property names and excludes circuits" do
    MapTiles::LayerContract.assert_no_circuit!

    MapTiles::LayerContract.layers.each do |layer|
      assert_no_match(/circuit/i, layer.name)

      layer.properties.each do |property|
        assert_no_match(/_/, property, "#{layer.name}.#{property} should be camelCase")
        assert_match(/\A[a-z][A-Za-z0-9]*\z/, property)
        assert_no_match(/circuit/i, property)
      end
    end
  end

  test "documents key layer properties" do
    assert_includes MapTiles::LayerContract.fetch("problems").optional_properties, "boulderId"
    assert_includes MapTiles::LayerContract.fetch("problems").optional_properties, "topoPhotoUrl"
    assert_includes MapTiles::LayerContract.fetch("problems").optional_properties, "lineCoordinatesJson"
    assert_includes MapTiles::LayerContract.fetch("walking_paths").required_properties, "walkingPathId"
    assert_includes MapTiles::LayerContract.fetch("pois").required_properties, "accessAreasJson"
    assert_includes MapTiles::LayerContract.fetch("areas").optional_properties, "coverPhotoUrl"
    assert_includes MapTiles::LayerContract.fetch("cluster_hulls").optional_properties, "parkingGoogleUrl"
    assert_includes MapTiles::LayerContract.fetch("regions").optional_properties, "mainClusterSouthWestLat"
    assert_includes MapTiles::LayerContract.fetch("region_hulls").optional_properties, "mainClusterNorthEastLon"
    assert_equal "LineString/MultiLineString", MapTiles::LayerContract.fetch("walking_paths").geometry_type
  end
end
