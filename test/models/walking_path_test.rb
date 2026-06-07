require "test_helper"

class WalkingPathTest < ActiveSupport::TestCase
  test "draft may omit slug and geometry" do
    walking_path = WalkingPath.new(label: "Draft path", published: false)

    assert walking_path.valid?
  end

  test "published requires slug and geometry" do
    walking_path = WalkingPath.new(label: "Published path", published: true)

    assert_not walking_path.valid?
    assert_includes walking_path.errors[:slug], "can't be blank"
    assert_includes walking_path.errors[:geometry], "must be present when published"
  end

  test "published accepts line string geometry" do
    result = WalkingPathGeojsonParser.parse(line_string_geojson)
    walking_path = WalkingPath.new(label: "Approach", slug: "approach", published: true, geometry: result.geometry)

    assert result.success?
    assert walking_path.valid?
  end

  test "published accepts multi line string geometry" do
    result = WalkingPathGeojsonParser.parse(<<~JSON)
      {"type":"MultiLineString","coordinates":[[[16.0,48.0],[16.1,48.1]],[[16.2,48.2],[16.3,48.3]]]}
    JSON
    walking_path = WalkingPath.new(label: "Connector", slug: "connector", published: true, geometry: result.geometry)

    assert result.success?
    assert walking_path.valid?
  end

  test "rejects unsupported geometry on the model" do
    walking_path = WalkingPath.new(label: "Point", geometry: FACTORY.point(16.0, 48.0))

    assert_not walking_path.valid?
    assert_includes walking_path.errors[:geometry], "must be a LineString or MultiLineString"
  end

  test "parser reports malformed json" do
    result = WalkingPathGeojsonParser.parse("not-json")

    assert_not result.success?
    assert_equal "GeoJSON is malformed JSON", result.error
  end

  test "parser rejects unsupported point and polygon geometry" do
    point = WalkingPathGeojsonParser.parse("{\"type\":\"Point\",\"coordinates\":[16.0,48.0]}")
    polygon = WalkingPathGeojsonParser.parse(<<~JSON)
      {"type":"Polygon","coordinates":[[[16.0,48.0],[16.1,48.0],[16.1,48.1],[16.0,48.0]]]}
    JSON

    assert_not point.success?
    assert_equal "GeoJSON must contain only LineString or MultiLineString geometries", point.error
    assert_not polygon.success?
    assert_equal "GeoJSON must contain only LineString or MultiLineString geometries", polygon.error
  end

  test "parser rejects feature collection with mixed line and unsupported geometry" do
    point_result = WalkingPathGeojsonParser.parse(<<~JSON)
      {
        "type":"FeatureCollection",
        "features":[
          {"type":"Feature","properties":{},"geometry":#{line_string_geojson}},
          {"type":"Feature","properties":{},"geometry":{"type":"Point","coordinates":[16.2,48.2]}}
        ]
      }
    JSON
    polygon_result = WalkingPathGeojsonParser.parse(<<~JSON)
      {
        "type":"FeatureCollection",
        "features":[
          {"type":"Feature","properties":{},"geometry":#{line_string_geojson}},
          {"type":"Feature","properties":{},"geometry":{"type":"Polygon","coordinates":[[[16.2,48.2],[16.3,48.2],[16.3,48.3],[16.2,48.2]]]}}
        ]
      }
    JSON

    assert_not point_result.success?
    assert_equal "GeoJSON must contain only LineString or MultiLineString geometries", point_result.error
    assert_not polygon_result.success?
    assert_equal "GeoJSON must contain only LineString or MultiLineString geometries", polygon_result.error
  end

  test "parser accepts feature with one line geometry" do
    result = WalkingPathGeojsonParser.parse(<<~JSON)
      {"type":"Feature","properties":{"name":"Approach"},"geometry":#{line_string_geojson}}
    JSON

    assert result.success?
    assert_kind_of RGeo::Feature::LineString, result.geometry
  end

  test "parser rejects feature collection with more than one line geometry" do
    result = WalkingPathGeojsonParser.parse(<<~JSON)
      {
        "type":"FeatureCollection",
        "features":[
          {"type":"Feature","properties":{},"geometry":#{line_string_geojson}},
          {"type":"Feature","properties":{},"geometry":{"type":"LineString","coordinates":[[16.2,48.2],[16.3,48.3]]}}
        ]
      }
    JSON

    assert_not result.success?
    assert_equal "GeoJSON must contain exactly one LineString or MultiLineString", result.error
  end

  test "optional area and cluster groupings" do
    area = Area.create!(name: "Walking Area", slug: "walking-area")
    cluster = Cluster.create!(name: "Walking Cluster", slug: "walking-cluster")
    walking_path = WalkingPath.create!(label: "Grouped draft", areas: [ area ], clusters: [ cluster ])

    assert_equal [ area ], walking_path.areas.to_a
    assert_equal [ cluster ], walking_path.clusters.to_a
    assert_equal [ walking_path ], area.walking_paths.to_a
    assert_equal [ walking_path ], cluster.walking_paths.to_a
  end

  test "geometry geojson helper encodes stored geometry" do
    result = WalkingPathGeojsonParser.parse(line_string_geojson)
    walking_path = WalkingPath.new(geometry: result.geometry)

    assert_includes walking_path.geometry_geojson, "LineString"
  end

  private

  def line_string_geojson
    "{\"type\":\"LineString\",\"coordinates\":[[16.0,48.0],[16.1,48.1]]}"
  end
end
