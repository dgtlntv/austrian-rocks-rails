require "test_helper"
require "tempfile"

class Admin::WalkingPathsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @area = Area.create!(name: "Controller Area", slug: "controller-area")
    @cluster = Cluster.create!(name: "Controller Cluster", slug: "controller-cluster")
  end

  test "index lists walking paths" do
    get admin_walking_paths_path(locale: :en)

    assert_response :success
    assert_includes response.body, walking_paths(:draft).label
  end

  test "new renders form" do
    get new_admin_walking_path_path(locale: :en)

    assert_response :success
    assert_includes response.body, "Paste GeoJSON"
  end

  test "create from pasted line string" do
    assert_difference "WalkingPath.count", 1 do
      post admin_walking_paths_path(locale: :en), params: {
        walking_path: {
          label: "Pasted approach",
          slug: "pasted-approach",
          published: "1",
          geojson_text: line_string_geojson,
          area_ids: [ @area.id ],
          cluster_ids: [ @cluster.id ]
        }
      }
    end

    walking_path = WalkingPath.order(:id).last
    assert_redirected_to edit_admin_walking_path_path(walking_path, locale: :en)
    assert_kind_of RGeo::Feature::LineString, walking_path.geometry
    assert_equal [ @area ], walking_path.areas.to_a
    assert_equal [ @cluster ], walking_path.clusters.to_a
  end

  test "create from uploaded geojson" do
    upload = Rack::Test::UploadedFile.new(
      Rails.root.join("test/fixtures/files/valid_walking_path.geojson"),
      "application/geo+json"
    )

    assert_difference "WalkingPath.count", 1 do
      post admin_walking_paths_path(locale: :en), params: {
        walking_path: {
          label: "Uploaded approach",
          slug: "uploaded-approach",
          published: "1",
          geojson_file: upload
        }
      }
    end

    assert_kind_of RGeo::Feature::LineString, WalkingPath.order(:id).last.geometry
  end

  test "edit and update walking path" do
    walking_path = walking_paths(:draft)

    get edit_admin_walking_path_path(walking_path, locale: :en)
    assert_response :success

    patch admin_walking_path_path(walking_path, locale: :en), params: {
      walking_path: {
        label: "Updated approach",
        slug: "updated-approach",
        description: "Updated description",
        published: "1",
        geojson_text: line_string_geojson
      }
    }

    assert_redirected_to edit_admin_walking_path_path(walking_path, locale: :en)
    walking_path.reload
    assert_equal "Updated approach", walking_path.label
    assert_equal "updated-approach", walking_path.slug
    assert walking_path.published?
    assert_kind_of RGeo::Feature::LineString, walking_path.geometry
  end

  test "update walking path from uploaded geojson" do
    walking_path = walking_paths(:published)
    upload = geojson_upload(updated_line_string_geojson)

    get edit_admin_walking_path_path(walking_path, locale: :en)
    assert_response :success
    assert_includes response.body, "Current geometry"
    assert_select "textarea#walking_path_geojson_text" do |textareas|
      assert_equal "", textareas.first.children.text.strip
    end

    patch admin_walking_path_path(walking_path, locale: :en), params: {
      walking_path: {
        label: "Uploaded replacement",
        slug: walking_path.slug,
        geojson_file: upload
      }
    }

    assert_redirected_to edit_admin_walking_path_path(walking_path, locale: :en)
    walking_path.reload
    assert_equal "Uploaded replacement", walking_path.label
    assert_equal 17.0, walking_path.geometry.points.first.x
    assert_equal 49.0, walking_path.geometry.points.first.y
  end

  test "publish walking path" do
    walking_path = walking_paths(:draft)
    walking_path.update!(slug: "publishable-path", geometry: parse_line)

    patch publish_admin_walking_path_path(walking_path, locale: :en)

    assert_redirected_to edit_admin_walking_path_path(walking_path, locale: :en)
    assert walking_path.reload.published?
  end

  test "unpublish walking path" do
    walking_path = walking_paths(:published)

    patch unpublish_admin_walking_path_path(walking_path, locale: :en)

    assert_redirected_to edit_admin_walking_path_path(walking_path, locale: :en)
    assert_not walking_path.reload.published?
  end

  test "destroy walking path" do
    walking_path = walking_paths(:draft)

    assert_difference "WalkingPath.count", -1 do
      delete admin_walking_path_path(walking_path, locale: :en)
    end

    assert_redirected_to admin_walking_paths_path(locale: :en)
  end

  test "malformed json does not create and shows error" do
    assert_no_difference "WalkingPath.count" do
      post admin_walking_paths_path(locale: :en), params: {
        walking_path: { label: "Bad", geojson_text: "not-json" }
      }
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "GeoJSON is malformed JSON"
  end

  test "unsupported point and polygon json do not create" do
    assert_no_difference "WalkingPath.count" do
      post admin_walking_paths_path(locale: :en), params: {
        walking_path: { label: "Point", geojson_text: point_geojson }
      }
    end
    assert_response :unprocessable_entity
    assert_includes response.body, "GeoJSON must contain only LineString or MultiLineString geometries"

    assert_no_difference "WalkingPath.count" do
      post admin_walking_paths_path(locale: :en), params: {
        walking_path: { label: "Polygon", geojson_text: polygon_geojson }
      }
    end
    assert_response :unprocessable_entity
    assert_includes response.body, "GeoJSON must contain only LineString or MultiLineString geometries"
  end

  test "multi-line feature collection is rejected" do
    assert_no_difference "WalkingPath.count" do
      post admin_walking_paths_path(locale: :en), params: {
        walking_path: { label: "Multi", geojson_text: multi_line_feature_collection_geojson }
      }
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "GeoJSON must contain exactly one LineString or MultiLineString"
  end

  test "uploaded invalid geojson is rejected" do
    upload = Rack::Test::UploadedFile.new(
      Rails.root.join("test/fixtures/files/invalid_walking_path.geojson"),
      "application/geo+json"
    )

    assert_no_difference "WalkingPath.count" do
      post admin_walking_paths_path(locale: :en), params: {
        walking_path: { label: "Invalid upload", geojson_file: upload }
      }
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "GeoJSON must contain only LineString or MultiLineString geometries"
  end

  test "invalid update does not partially save metadata or groupings" do
    walking_path = walking_paths(:draft)
    original_label = walking_path.label

    patch admin_walking_path_path(walking_path, locale: :en), params: {
      walking_path: {
        label: "Should not persist",
        area_ids: [ @area.id ],
        cluster_ids: [ @cluster.id ],
        geojson_text: point_geojson
      }
    }

    assert_response :unprocessable_entity
    walking_path.reload
    assert_equal original_label, walking_path.label
    assert_empty walking_path.area_ids
    assert_empty walking_path.cluster_ids
  end

  private

  def parse_line
    WalkingPathGeojsonParser.parse(line_string_geojson).geometry
  end

  def geojson_upload(contents)
    file = Tempfile.new([ "walking-path", ".geojson" ])
    file.write(contents)
    file.rewind
    Rack::Test::UploadedFile.new(file.path, "application/geo+json")
  end

  def line_string_geojson
    "{\"type\":\"LineString\",\"coordinates\":[[16.0,48.0],[16.1,48.1]]}"
  end

  def updated_line_string_geojson
    "{\"type\":\"LineString\",\"coordinates\":[[17.0,49.0],[17.1,49.1]]}"
  end

  def point_geojson
    "{\"type\":\"Point\",\"coordinates\":[16.0,48.0]}"
  end

  def polygon_geojson
    <<~JSON
      {"type":"Polygon","coordinates":[[[16.0,48.0],[16.1,48.0],[16.1,48.1],[16.0,48.0]]]}
    JSON
  end

  def multi_line_feature_collection_geojson
    <<~JSON
      {
        "type":"FeatureCollection",
        "features":[
          {"type":"Feature","properties":{},"geometry":#{line_string_geojson}},
          {"type":"Feature","properties":{},"geometry":{"type":"LineString","coordinates":[[16.2,48.2],[16.3,48.3]]}}
        ]
      }
    JSON
  end
end
