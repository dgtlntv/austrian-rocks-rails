# frozen_string_literal: true

require "test_helper"

class MapControllerTest < ActionDispatch::IntegrationTest
  setup do
    @area = Area.create!(name: "Test Area", slug: "test-area", published: true)
    Boulder.create!(area: @area, polygon: polygon([ [ 16.0, 47.0 ], [ 16.1, 47.0 ], [ 16.1, 47.1 ], [ 16.0, 47.1 ], [ 16.0, 47.0 ] ]))
    @problem = Problem.create!(id: 123, area: @area, name: "Test Problem", grade: "6a", steepness: "wall", location: point(16.05, 47.05))
  end

  test "public map renders MapLibre markup without Mapbox runtime assets" do
    get "/en/map"

    assert_response :success
    assert_maplibre_page
    assert_no_mapbox_runtime
    assert_includes response.body, 'data-map-contribute-value="false"'
  end

  test "area map renders bounds data for MapLibre controller" do
    get "/en/map/test-area"

    assert_response :success
    assert_maplibre_page
    assert_no_mapbox_runtime
    assert_includes response.body, 'data-map-bounds-value='
    assert_includes response.body, "southWestLon"
    assert_includes response.body, "northEastLat"
  end

  test "problem deep link renders problem data for MapLibre controller" do
    get "/en/map", params: { pid: @problem.id }

    assert_response :success
    assert_maplibre_page
    assert_no_mapbox_runtime
    assert_includes response.body, 'data-map-problem-value='
    assert_includes response.body, "Test Problem"
    assert_includes response.body, "6a"
  end

  test "public problem popups use PMTiles problem ids" do
    controller_source = Rails.root.join("app/javascript/controllers/map_controller.js").read

    assert_includes controller_source, "problem.id ?? problem.problemId"
    assert_includes controller_source, "encodeURIComponent(problemId)"
    assert_not_includes controller_source, "problem_id=${encodeURIComponent(problem.id)}"
  end

  test "contribution map renders contribution source for MapLibre controller" do
    get "/en/mapping/map"

    assert_response :success
    assert_maplibre_page
    assert_no_mapbox_runtime
    assert_includes response.body, 'data-map-contribute-value="true"'
    assert_includes response.body, 'data-map-contribute-source-value="/en/mapping/requests.geojson"'
  end

  private

  def assert_maplibre_page
    assert_includes response.body, 'data-controller="map"'
    assert_includes response.body, 'data-map-target="map"'
    assert_includes response.body, 'data-map-manifest-url-value="https://tiles.austrian.rocks/map_tiles/current.json"'
    assert_includes response.body, 'data-map-style-value="light"'
    assert_includes response.body, "maplibre-gl@5.24.0/dist/maplibre-gl.css"
    assert_includes response.body, '"maplibre-gl"'
    assert_includes response.body, '"pmtiles"'
  end

  def assert_no_mapbox_runtime
    assert_not_includes response.body, "MAPBOX_DEV_ACCESS_KEY"
    assert_not_includes response.body, "data-mapbox-token-value"
    assert_not_includes response.body, "api.mapbox.com"
    assert_not_includes response.body, "mapbox://"
    assert_not_includes response.body, "mapbox-gl.js"
  end

  def point(lon, lat)
    FACTORY.point(lon, lat)
  end

  def polygon(coordinates)
    FACTORY.polygon(FACTORY.line_string(coordinates.map { |lon, lat| point(lon, lat) }))
  end
end
