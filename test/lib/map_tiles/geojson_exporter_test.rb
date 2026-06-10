# frozen_string_literal: true

require "test_helper"
require "base64"
require "json"
require "securerandom"
require "stringio"
require "tmpdir"
require "map_tiles/layer_contract"
require "map_tiles/configuration"
require "map_tiles/geojson_exporter"

class MapTiles::GeojsonExporterTest < ActiveSupport::TestCase
  PNG_FIXTURE = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII="

  setup do
    @output_dir = Rails.root.join("tmp/map_tiles_exporter_test/#{SecureRandom.hex(8)}")
    @configuration = MapTiles::Configuration.new(version: "test-version", settings: map_tile_settings)

    create_map_records
  end

  teardown do
    FileUtils.rm_rf(@output_dir)
  end

  test "exports one deterministic GeoJSON FeatureCollection per expected layer" do
    paths = MapTiles::GeojsonExporter.new(configuration: @configuration).export

    assert_equal MapTiles::LayerContract.layer_names, paths.keys
    paths.each do |layer_name, path|
      assert_predicate path, :exist?
      json = JSON.parse(path.read)

      assert_equal "FeatureCollection", json.fetch("type")
      assert json.fetch("features").any?, "expected #{layer_name} to contain fixture-backed features"
    end
  end

  test "exports contract properties with camelCase names and no app canonical urls" do
    paths = MapTiles::GeojsonExporter.new(configuration: @configuration).export

    problem = feature_properties(paths.fetch("problems"), "problemId", @problem.id)
    assert_equal @area.id, problem.fetch("areaId")
    assert_equal @area.slug, problem.fetch("areaSlug")
    assert_equal @boulder.id, problem.fetch("boulderId")
    assert_equal "6a", problem.fetch("grade")
    assert_equal true, problem.fetch("featured")
    assert_no_canonical_url(problem)

    boulder = feature_properties(paths.fetch("boulders"), "boulderId", @boulder.id)
    assert_equal @area.slug, boulder.fetch("areaSlug")
    assert_equal "Test Boulder", boulder.fetch("name")

    area = feature_properties(paths.fetch("areas"), "areaId", @area.id)
    assert_equal "TA", area.fetch("shortName")
    area_hull = feature_properties(paths.fetch("area_hulls"), "areaId", @area.id)
    assert_not_includes area_hull, "shortName"

    walking_path = feature_properties(paths.fetch("walking_paths"), "walkingPathId", @walking_path.id)
    assert_equal @walking_path.slug, walking_path.fetch("slug")
    assert_equal @walking_path.label, walking_path.fetch("name")
    assert_equal @walking_path.description, walking_path.fetch("description")

    poi = feature_properties(paths.fetch("pois"), "poiId", @poi.id)
    assert_equal "parking", poi.fetch("poiType")
    assert_equal @poi.google_url, poi.fetch("googleUrl")
    assert_no_canonical_url(poi)
  end

  test "cascades card metadata from own entity to cluster to region" do
    region_guidebook = Guidebook.create!(title: "Region Guide", author: "R Author", url: "https://guides.example/region")
    cluster_guidebook = Guidebook.create!(title: "Cluster Guide", author: "C Author", url: "https://guides.example/cluster")
    area_guidebook = Guidebook.create!(title: "Area Guide", author: "A Author", url: "https://guides.example/area")
    region_parking = create_parking("Region Parking", "https://maps.example/region")
    cluster_parking = create_parking("Cluster Parking", "https://maps.example/cluster")
    area_parking = create_parking("Area Parking", "https://maps.example/area")

    @region.update!(warning_de: "Region warning", warning_en: "Region warning EN", guidebook: region_guidebook, parking_poi: region_parking)
    @cluster.update!(warning_de: "Cluster warning", warning_en: "Cluster warning EN", guidebook: cluster_guidebook, parking_poi: cluster_parking)
    @area.update!(warning_de: "Area warning", warning_en: "Area warning EN", guidebook: area_guidebook, parking_poi: area_parking)
    area_from_cluster = create_area_with_boulder(cluster: @cluster, name: "Cluster cascade area")
    cluster_from_region = create_cluster(region: @region, name: "Region cascade cluster")
    area_from_region = create_area_with_boulder(cluster: cluster_from_region, name: "Region cascade area")
    empty_region = create_region(name: "Empty card region")
    empty_cluster = create_cluster(region: empty_region, name: "Empty card cluster")
    empty_area = create_area_with_boulder(cluster: empty_cluster, name: "Empty card area")

    paths = MapTiles::GeojsonExporter.new(configuration: @configuration).export

    own_area = feature_properties(paths.fetch("areas"), "areaId", @area.id)
    assert_equal "Area warning", own_area.fetch("warning")
    assert_equal "Area warning EN", own_area.fetch("warningEn")
    assert_equal "Area Guide", own_area.fetch("guidebookTitle")
    assert_equal "A Author", own_area.fetch("guidebookAuthor")
    assert_equal "https://guides.example/area", own_area.fetch("guidebookUrl")
    assert_equal area_parking.id, own_area.fetch("parkingPoiId")
    assert_equal "Area Parking", own_area.fetch("parkingName")
    assert_equal "https://maps.example/area", own_area.fetch("parkingGoogleUrl")

    inherited_from_cluster = feature_properties(paths.fetch("areas"), "areaId", area_from_cluster.id)
    assert_equal "Cluster warning", inherited_from_cluster.fetch("warning")
    assert_equal "Cluster Guide", inherited_from_cluster.fetch("guidebookTitle")
    assert_equal cluster_parking.id, inherited_from_cluster.fetch("parkingPoiId")

    inherited_from_region = feature_properties(paths.fetch("areas"), "areaId", area_from_region.id)
    assert_equal "Region warning", inherited_from_region.fetch("warning")
    assert_equal "Region Guide", inherited_from_region.fetch("guidebookTitle")
    assert_equal region_parking.id, inherited_from_region.fetch("parkingPoiId")

    cluster_props = feature_properties(paths.fetch("clusters"), "clusterId", @cluster.id)
    assert_equal "Cluster warning", cluster_props.fetch("warning")
    assert_equal "Cluster Guide", cluster_props.fetch("guidebookTitle")

    region_props = feature_properties(paths.fetch("regions"), "regionId", @region.id)
    assert_equal "Region warning", region_props.fetch("warning")
    assert_equal "Region Guide", region_props.fetch("guidebookTitle")

    missing = feature_properties(paths.fetch("areas"), "areaId", empty_area.id)
    assert_not_includes missing, "warning"
    assert_not_includes missing, "warningEn"
    assert_not_includes missing, "guidebookTitle"
    assert_not_includes missing, "parkingPoiId"
  end

  test "exports problem counts and grade ranges over published areas only" do
    unpublished_area = create_area_with_boulder(cluster: @cluster, name: "Draft area", published: false)
    Problem.create!(
      area: unpublished_area,
      boulder: unpublished_area.boulders.first,
      name: "Draft hard problem",
      grade: "9a",
      steepness: "wall",
      location: point(16.31, 48.31)
    )

    paths = MapTiles::GeojsonExporter.new(configuration: @configuration).export

    area = feature_properties(paths.fetch("areas"), "areaId", @area.id)
    assert_equal 2, area.fetch("problemCount")
    assert_equal "5a", area.fetch("gradeMin")
    assert_equal "6a", area.fetch("gradeMax")

    cluster = feature_properties(paths.fetch("clusters"), "clusterId", @cluster.id)
    assert_equal 2, cluster.fetch("problemCount")
    assert_equal "5a", cluster.fetch("gradeMin")
    assert_equal "6a", cluster.fetch("gradeMax")

    region = feature_properties(paths.fetch("regions"), "regionId", @region.id)
    assert_equal 2, region.fetch("problemCount")
    assert_equal "5a", region.fetch("gradeMin")
    assert_equal "6a", region.fetch("gradeMax")
  end

  test "exports region main cluster bounds when configured" do
    @region.update!(main_cluster_id: @cluster.id)

    paths = MapTiles::GeojsonExporter.new(configuration: @configuration).export

    region = feature_properties(paths.fetch("regions"), "regionId", @region.id)
    assert_equal 48.0, region.fetch("mainClusterSouthWestLat")
    assert_equal 16.0, region.fetch("mainClusterSouthWestLon")
    assert_equal 48.1, region.fetch("mainClusterNorthEastLat")
    assert_equal 16.1, region.fetch("mainClusterNorthEastLon")

    @region.update!(main_cluster_id: nil)
    paths = MapTiles::GeojsonExporter.new(configuration: @configuration).export
    region = feature_properties(paths.fetch("regions"), "regionId", @region.id)
    assert_not_includes region, "mainClusterSouthWestLat"
  end

  test "exports deterministic cover photo URLs" do
    @area.cover.attach(
      io: StringIO.new(Base64.decode64(PNG_FIXTURE)),
      filename: "cover.png",
      content_type: "image/png"
    )

    first_paths = MapTiles::GeojsonExporter.new(configuration: @configuration).export
    first_url = feature_properties(first_paths.fetch("areas"), "areaId", @area.id).fetch("coverPhotoUrl")

    second_paths = MapTiles::GeojsonExporter.new(configuration: @configuration).export
    second_url = feature_properties(second_paths.fetch("areas"), "areaId", @area.id).fetch("coverPhotoUrl")

    assert_equal first_url, second_url
    assert_match(%r{/rails/active_storage/representations/proxy/}, first_url)

    @area.cover.purge
    paths = MapTiles::GeojsonExporter.new(configuration: @configuration).export
    area = feature_properties(paths.fetch("areas"), "areaId", @area.id)
    assert_not_includes area, "coverPhotoUrl"
  end

  test "encodes POI access area metadata as a scalar JSON string" do
    paths = MapTiles::GeojsonExporter.new(configuration: @configuration).export

    poi = feature_properties(paths.fetch("pois"), "poiId", @poi.id)
    assert_kind_of String, poi.fetch("accessAreasJson")

    access_areas = JSON.parse(poi.fetch("accessAreasJson"))
    assert_equal [ {
      "areaId" => @area.id,
      "areaSlug" => @area.slug,
      "transport" => "walking",
      "distance" => 1200,
      "minutes" => 15
    } ], access_areas
  end

  test "keeps required properties when valid source labels or grades are blank" do
    @problem.update!(name: nil, grade: nil)
    @area.update!(name: nil)
    @cluster.update!(name: nil)
    @region.update!(name: nil)
    @walking_path.update!(label: nil)
    @poi.update!(name: nil)

    paths = MapTiles::GeojsonExporter.new(configuration: @configuration).export

    problem = feature_properties(paths.fetch("problems"), "problemId", @problem.id)
    assert_equal I18n.with_locale(:de) { I18n.t("problem.no_name") }, problem.fetch("name")
    assert_equal "unknown", problem.fetch("grade")

    area = feature_properties(paths.fetch("areas"), "areaId", @area.id)
    assert_equal @area.slug, area.fetch("name")

    cluster = feature_properties(paths.fetch("clusters"), "clusterId", @cluster.id)
    assert_equal @cluster.slug, cluster.fetch("name")

    region = feature_properties(paths.fetch("regions"), "regionId", @region.id)
    assert_equal @region.slug, region.fetch("name")

    walking_path = feature_properties(paths.fetch("walking_paths"), "walkingPathId", @walking_path.id)
    assert_equal @walking_path.slug, walking_path.fetch("name")

    poi = feature_properties(paths.fetch("pois"), "poiId", @poi.id)
    assert_equal @poi.short_name, poi.fetch("name")
  end

  test "exports published walking paths only" do
    draft = WalkingPath.create!(label: "Draft connector", slug: nil, published: false)

    paths = MapTiles::GeojsonExporter.new(configuration: @configuration).export
    walking_path_ids = JSON.parse(paths.fetch("walking_paths").read).fetch("features").map do |feature|
      feature.fetch("properties").fetch("walkingPathId")
    end

    assert_includes walking_path_ids, @walking_path.id
    assert_not_includes walking_path_ids, draft.id
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

  def create_map_records
    @region = Region.create!(
      name: "Test Region",
      slug: "test-region-#{SecureRandom.hex(4)}",
      published: true,
      center: point(16.05, 48.05),
      sw: point(16.0, 48.0),
      ne: point(16.1, 48.1)
    )
    @cluster = Cluster.create!(
      name: "Test Cluster",
      slug: "test-cluster-#{SecureRandom.hex(4)}",
      published: true,
      region: @region,
      center: point(16.05, 48.05),
      sw: point(16.0, 48.0),
      ne: point(16.1, 48.1)
    )
    @area = Area.create!(
      name: "Test Area",
      short_name: "TA",
      slug: "test-area-#{SecureRandom.hex(4)}",
      published: true,
      priority: 1,
      cluster: @cluster
    )
    @boulder = Boulder.create!(area: @area, name: "Test Boulder", polygon: polygon([
      [ 16.00, 48.00 ],
      [ 16.10, 48.00 ],
      [ 16.10, 48.10 ],
      [ 16.00, 48.10 ],
      [ 16.00, 48.00 ]
    ]))
    ignored = Boulder.create!(area: @area, name: "Ignored for hull only", ignore_for_area_hull: true, polygon: polygon([
      [ 16.20, 48.20 ],
      [ 16.25, 48.20 ],
      [ 16.25, 48.25 ],
      [ 16.20, 48.25 ],
      [ 16.20, 48.20 ]
    ]))
    @problem = Problem.create!(
      area: @area,
      boulder: @boulder,
      name: "Test Problem",
      grade: "6a",
      steepness: "wall",
      featured: true,
      popularity: 10,
      landing: "easy",
      height: 3,
      location: point(16.05, 48.05)
    )
    Problem.create!(
      area: @area,
      boulder: ignored,
      name: "Ignored Boulder Problem",
      grade: "5a",
      steepness: "slab",
      location: point(16.21, 48.21)
    )
    @walking_path = WalkingPath.create!(
      label: "Test Approach",
      slug: "test-approach-#{SecureRandom.hex(4)}",
      description: "Approach description",
      published: true,
      geometry: line_string([ [ 16.0, 48.0 ], [ 16.1, 48.1 ] ])
    )
    @poi = Poi.create!(
      name: "Test Parking",
      short_name: "Parking",
      google_url: "https://maps.google.example/?q=test",
      poi_type: "parking",
      location: point(16.02, 48.02)
    )
    PoiRoute.create!(poi: @poi, area: @area, transport: "walking", distance: 1200)
  end

  def feature_properties(path, property_name, value)
    JSON.parse(path.read).fetch("features").find do |feature|
      feature.fetch("properties").fetch(property_name) == value
    end.fetch("properties")
  end

  def assert_no_canonical_url(properties)
    properties.each_key do |key|
      next if %w[coverPhotoUrl guidebookUrl googleUrl parkingGoogleUrl].include?(key)

      assert_no_match(/url/i, key)
    end
  end

  def create_region(name:)
    Region.create!(
      name: name,
      slug: "#{name.parameterize}-#{SecureRandom.hex(4)}",
      published: true,
      center: point(16.05, 48.05),
      sw: point(16.0, 48.0),
      ne: point(16.1, 48.1)
    )
  end

  def create_cluster(region:, name:)
    Cluster.create!(
      name: name,
      slug: "#{name.parameterize}-#{SecureRandom.hex(4)}",
      published: true,
      region: region,
      center: point(16.05, 48.05),
      sw: point(16.0, 48.0),
      ne: point(16.1, 48.1)
    )
  end

  def create_area_with_boulder(cluster:, name:, published: true)
    area = Area.create!(
      name: name,
      slug: "#{name.parameterize}-#{SecureRandom.hex(4)}",
      published: published,
      priority: 1,
      cluster: cluster
    )
    Boulder.create!(area: area, name: "#{name} Boulder", polygon: polygon([
      [ 16.30, 48.30 ],
      [ 16.35, 48.30 ],
      [ 16.35, 48.35 ],
      [ 16.30, 48.35 ],
      [ 16.30, 48.30 ]
    ]))
    area
  end

  def create_parking(name, google_url)
    Poi.create!(
      name: name,
      short_name: name,
      google_url: google_url,
      poi_type: "parking",
      location: point(16.03, 48.03)
    )
  end

  def point(lon, lat)
    FACTORY.point(lon, lat)
  end

  def line_string(coordinates)
    FACTORY.line_string(coordinates.map { |lon, lat| point(lon, lat) })
  end

  def polygon(coordinates)
    FACTORY.polygon(line_string(coordinates))
  end
end
