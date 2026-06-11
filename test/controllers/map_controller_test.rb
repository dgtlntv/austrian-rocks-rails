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
    assert_not_includes response.body, 'data-map-target="zoom"'
    assert_not_includes response.body, "z –"
    assert_includes response.body, "pointer-events-none absolute inset-x-0 bottom-0"
    assert_includes response.body, "pointer-events-auto inline-flex"
  end

  test "area map renders bounds data for MapLibre controller" do
    get "/en/map/test-area"

    assert_response :success
    assert_maplibre_page
    assert_no_mapbox_runtime
    assert_includes response.body, "data-map-bounds-value="
    assert_includes response.body, "southWestLon"
    assert_includes response.body, "northEastLat"
  end

  test "map page renders the info card target with localized card strings" do
    get "/en/map"

    assert_response :success
    assert_includes response.body, 'data-map-target="card"'
    assert_includes response.body, "data-map-card-strings-value="
    assert_includes response.body, "Zoom to place"
    assert_not_includes response.body, "data-map-area-id-value"

    get "/de/map"

    assert_response :success
    assert_includes response.body, "Zum Ort zoomen"
  end

  test "area slug deep link renders the area id for MapLibre controller" do
    get "/en/map/test-area"

    assert_response :success
    assert_includes response.body, "data-map-area-id-value=\"#{@area.id}\""
  end

  test "problem deep link renders problem data for MapLibre controller" do
    get "/en/map", params: { pid: @problem.id }

    assert_response :success
    assert_maplibre_page
    assert_no_mapbox_runtime
    assert_includes response.body, "data-map-problem-value="
    assert_includes response.body, "Test Problem"
    assert_includes response.body, "6a"
  end

  test "problem query alias renders problem data for MapLibre controller" do
    get "/en/map", params: { problem: @problem.id }

    assert_response :success
    assert_maplibre_page
    assert_includes response.body, "data-map-problem-value="
    assert_includes response.body, "Test Problem"
  end

  test "MapLibre controller selects cards for search and deep links without legacy problem popups" do
    controller_source = Rails.root.join("app/javascript/controllers/map_controller.js").read

    assert_includes controller_source, "selectFeatureWhenIdle"
    assert_not_includes controller_source, "problemPopupContent"
    assert_not_includes controller_source, "poiPopupContent"
    assert_not_includes controller_source, "Math.max(15,"
    assert_includes controller_source, "maxBounds: AUSTRIA_MAX_BOUNDS"
    assert_includes controller_source, "setMinZoom"
    assert_includes controller_source, 'registerSelectClicks("problems", "problem", (zoom) => zoom >= 15)'
    assert_includes controller_source, 'registerSelectClicks("areas", "area", (zoom) => zoom < 16)'
    assert_includes controller_source, "lastInteractiveClickEvent"
    assert_includes controller_source, "selectionBounds"
    assert_not_includes controller_source, "map.setPadding({ top: 0, bottom: 0, left: 0, right: 0 })"
  end

  test "MapLibre controller keeps default attribution control clickable without temporary zoom readout" do
    controller_source = Rails.root.join("app/javascript/controllers/map_controller.js").read

    assert_not_includes controller_source, "attributionControl: false"
    assert_not_includes controller_source, "new maplibregl.AttributionControl"
    assert_not_includes controller_source, "compact: false"
    assert_not_includes controller_source, "stopPropagation"
    assert_not_includes controller_source, "preventDefault"
    assert_not_includes controller_source, "updateZoomIndicator"
    assert_not_includes controller_source, "getZoom().toFixed(2)"
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
    assert_not_includes response.body, forbidden_map_token_env
    assert_not_includes response.body, "data-mapbox" + "-token-value"
    assert_not_includes response.body, "api." + "mapbox.com"
    assert_not_includes response.body, "mapbox:" + "//"
    assert_not_includes response.body, "mapbox-gl.js"
  end

  def forbidden_map_token_env
    "MAPBOX" + "_DEV_ACCESS_KEY"
  end

  def point(lon, lat)
    FACTORY.point(lon, lat)
  end

  def polygon(coordinates)
    FACTORY.polygon(FACTORY.line_string(coordinates.map { |lon, lat| point(lon, lat) }))
  end
end
