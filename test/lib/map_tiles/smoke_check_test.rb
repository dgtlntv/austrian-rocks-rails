# frozen_string_literal: true

require "test_helper"
require "json"
require "securerandom"
require "stringio"
require "map_tiles/smoke_check"

class MapTiles::SmokeCheckTest < ActiveSupport::TestCase
  setup do
    @output_dir = Rails.root.join("tmp/smoke_check_test/#{SecureRandom.hex(8)}")
    @configuration = MapTiles::Configuration.new(env: {
      "MAP_TILES_OUTPUT_DIR" => @output_dir.to_s,
      "MAP_TILES_VERSION" => "test-version"
    })

    FileUtils.mkdir_p(@configuration.geojson_dir)
    write_pmtiles_artifact
    write_geojson_layers
  end

  teardown do
    FileUtils.rm_rf(@output_dir)
  end

  test "passes production smoke checks for dataful fixture layers" do
    out = StringIO.new

    result = MapTiles::SmokeCheck.new(configuration: @configuration, argv: [ "--mode=production" ], out: out).run

    assert_equal "production", result.fetch(:mode)
    assert_equal MapTiles::LayerContract.layer_names, result.fetch(:layers).map { |layer| layer.fetch(:name) }
    assert_includes out.string, "PMTiles smoke check passed"
    assert_includes out.string, "walking_paths: 1 feature(s)"
    assert_includes out.string, "bounds: lon"
  end

  test "fails when the PMTiles artifact is missing or empty" do
    FileUtils.rm_f(@configuration.artifact_path)

    error = assert_raises(MapTiles::SmokeCheck::Error) do
      MapTiles::SmokeCheck.new(configuration: @configuration).check
    end
    assert_includes error.message, "PMTiles artifact is missing"

    @configuration.artifact_path.write("")
    error = assert_raises(MapTiles::SmokeCheck::Error) do
      MapTiles::SmokeCheck.new(configuration: @configuration).check
    end
    assert_includes error.message, "PMTiles artifact is empty"
  end

  test "fails when the PMTiles artifact is not a PMTiles archive" do
    @configuration.artifact_path.write("pmtiles fixture")

    error = assert_raises(MapTiles::SmokeCheck::Error) do
      MapTiles::SmokeCheck.new(configuration: @configuration).check
    end

    assert_includes error.message, "PMTiles artifact is not a valid PMTiles v3 archive"
  end

  test "allows Tippecanoe metadata layer ordering and absent optional fields" do
    write_pmtiles_artifact(
      layers: MapTiles::LayerContract.layers.reverse,
      field_overrides: MapTiles::LayerContract.layers.to_h { |layer| [ layer.name, layer.required_properties ] }
    )

    result = MapTiles::SmokeCheck.new(configuration: @configuration).check

    assert_equal "production", result.fetch(:mode)
  end

  test "fails when PMTiles metadata layers or required field names do not match the contract" do
    write_pmtiles_artifact(layers: MapTiles::LayerContract.layers.reject { |layer| layer.name == "pois" })

    error = assert_raises(MapTiles::SmokeCheck::Error) do
      MapTiles::SmokeCheck.new(configuration: @configuration).check
    end

    assert_includes error.message, "PMTiles metadata layers mismatch"

    write_pmtiles_artifact(field_overrides: { "problems" => %w[problemId areaId unexpectedField canonicalUrl circuitId] })
    error = assert_raises(MapTiles::SmokeCheck::Error) do
      MapTiles::SmokeCheck.new(configuration: @configuration).check
    end

    assert_includes error.message, "PMTiles metadata fields mismatch for problems"
    assert_includes error.message, "missing required fields: areaSlug, name, grade, steepness, featured"
    assert_includes error.message, "unexpected fields: canonicalUrl, circuitId, unexpectedField"
    assert_includes error.message, "PMTiles metadata layer problems has forbidden app URL field: canonicalUrl"
    assert_includes error.message, "PMTiles metadata layer problems has forbidden circuit field: circuitId"
  end

  test "fails when sampled GeoJSON features miss required properties" do
    update_layer("problems") do |collection|
      collection.fetch("features").first.fetch("properties").delete("grade")
    end

    error = assert_raises(MapTiles::SmokeCheck::Error) do
      MapTiles::SmokeCheck.new(configuration: @configuration).check
    end

    assert_includes error.message, "problems feature 0 is missing required properties: grade"
  end

  test "fails when combined feature bounds leave sane Austria bounds" do
    update_layer("pois") do |collection|
      collection.fetch("features").first["geometry"] = point_geometry(18.0, 48.0)
    end

    error = assert_raises(MapTiles::SmokeCheck::Error) do
      MapTiles::SmokeCheck.new(configuration: @configuration).check
    end

    assert_includes error.message, "outside sane Austria bounds"
  end

  test "fails on zero feature layers in production mode" do
    update_layer("pois") do |collection|
      collection["features"] = []
    end

    error = assert_raises(MapTiles::SmokeCheck::Error) do
      MapTiles::SmokeCheck.new(configuration: @configuration, argv: [ "--mode=production" ]).check
    end

    assert_includes error.message, "pois has zero features in production mode"
  end

  test "allows configured zero feature layers in relaxed mode" do
    update_layer("pois") do |collection|
      collection["features"] = []
    end

    result = MapTiles::SmokeCheck.new(
      configuration: @configuration,
      argv: [ "--mode=relaxed", "--allow-empty=pois" ]
    ).check

    assert_equal "relaxed", result.fetch(:mode)
    assert_equal 0, result.fetch(:layers).find { |layer| layer.fetch(:name) == "pois" }.fetch(:count)
  end

  test "rejects circuit fields, app URL fields, and non-scalar properties" do
    update_layer("problems") do |collection|
      properties = collection.fetch("features").first.fetch("properties")
      properties["circuitId"] = 123
      properties["canonicalUrl"] = "https://example.test/problems/1"
      properties["name"] = [ "not", "scalar" ]
    end

    error = assert_raises(MapTiles::SmokeCheck::Error) do
      MapTiles::SmokeCheck.new(configuration: @configuration).check
    end

    assert_includes error.message, "forbidden circuit field: circuitId"
    assert_includes error.message, "forbidden app URL field: canonicalUrl"
    assert_includes error.message, "property name is not scalar"
  end

  private

  def write_pmtiles_artifact(layers: MapTiles::LayerContract.layers, field_overrides: {})
    metadata_json = JSON.generate({
      "vector_layers" => layers.map do |layer|
        fields = field_overrides.fetch(layer.name, layer.properties)
        {
          "id" => layer.name,
          "fields" => fields.to_h { |property| [ property, "Scalar" ] }
        }
      end
    })

    header = "\0".b * 127
    header[0, 7] = "PMTiles"
    header.setbyte(7, 3)
    header[24, 8] = [ 127 ].pack("Q<")
    header[32, 8] = [ metadata_json.bytesize ].pack("Q<")
    header.setbyte(97, 1)

    @configuration.artifact_path.binwrite(header + metadata_json)
  end

  def write_geojson_layers
    MapTiles::LayerContract.layers.each do |layer|
      path = @configuration.geojson_dir.join("#{layer.name}.geojson")
      path.write(JSON.pretty_generate(feature_collection_for(layer)))
    end
  end

  def update_layer(layer_name)
    path = @configuration.geojson_dir.join("#{layer_name}.geojson")
    collection = JSON.parse(path.read)
    yield collection
    path.write(JSON.pretty_generate(collection))
  end

  def feature_collection_for(layer)
    {
      "type" => "FeatureCollection",
      "features" => [ {
        "type" => "Feature",
        "properties" => required_properties_for(layer),
        "geometry" => geometry_for(layer)
      } ]
    }
  end

  def required_properties_for(layer)
    layer.required_properties.to_h do |property|
      [ property, property_value(property) ]
    end
  end

  def property_value(property)
    case property
    when /Id\z/
      1
    when /Lat\z/
      48.0
    when /Lon\z/
      16.0
    when "featured"
      true
    when "accessAreasJson"
      "[]"
    else
      "test-#{property}"
    end
  end

  def geometry_for(layer)
    case layer.geometry_type
    when "Point"
      point_geometry(16.0, 48.0)
    when "Polygon"
      {
        "type" => "Polygon",
        "coordinates" => [ [ [ 16.0, 48.0 ], [ 16.1, 48.0 ], [ 16.1, 48.1 ], [ 16.0, 48.1 ], [ 16.0, 48.0 ] ] ]
      }
    when "LineString/MultiLineString"
      {
        "type" => "LineString",
        "coordinates" => [ [ 16.0, 48.0 ], [ 16.1, 48.1 ] ]
      }
    else
      raise "Unhandled geometry type: #{layer.geometry_type}"
    end
  end

  def point_geometry(lon, lat)
    {
      "type" => "Point",
      "coordinates" => [ lon, lat ]
    }
  end
end
