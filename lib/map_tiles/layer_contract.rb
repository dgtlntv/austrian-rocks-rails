# frozen_string_literal: true

module MapTiles
  class LayerContract
    Layer = Struct.new(:name, :geometry_type, :required_properties, :optional_properties, keyword_init: true) do
      def properties
        required_properties + optional_properties
      end
    end

    NATIVE_MAX_ZOOM = 16

    LAYERS = [
      Layer.new(
        name: "problems",
        geometry_type: "Point",
        required_properties: %w[problemId areaId areaSlug name grade steepness featured],
        optional_properties: %w[boulderId nameEn popularity landing height parentProblemId topoPhotoUrl lineCoordinatesJson]
      ),
      Layer.new(
        name: "boulders",
        geometry_type: "Polygon",
        required_properties: %w[boulderId areaId areaSlug],
        optional_properties: %w[name]
      ),
      Layer.new(
        name: "areas",
        geometry_type: "Point",
        required_properties: %w[areaId areaSlug name priority southWestLat southWestLon northEastLat northEastLon],
        optional_properties: %w[nameEn shortName clusterId clusterSlug problemCount gradeMin gradeMax gradeHistogramJson coverPhotoUrl warning warningEn guidebookTitle guidebookAuthor guidebookUrl parkingPoiId parkingName parkingGoogleUrl]
      ),
      Layer.new(
        name: "area_hulls",
        geometry_type: "Polygon",
        required_properties: %w[areaId areaSlug southWestLat southWestLon northEastLat northEastLon],
        optional_properties: %w[name nameEn priority problemCount gradeMin gradeMax gradeHistogramJson coverPhotoUrl warning warningEn guidebookTitle guidebookAuthor guidebookUrl parkingPoiId parkingName parkingGoogleUrl]
      ),
      Layer.new(
        name: "clusters",
        geometry_type: "Point",
        required_properties: %w[clusterId clusterSlug name southWestLat southWestLon northEastLat northEastLon],
        optional_properties: %w[nameEn regionId regionSlug mainAreaId mainAreaSlug problemCount gradeMin gradeMax gradeHistogramJson coverPhotoUrl warning warningEn guidebookTitle guidebookAuthor guidebookUrl parkingPoiId parkingName parkingGoogleUrl]
      ),
      Layer.new(
        name: "cluster_hulls",
        geometry_type: "Polygon",
        required_properties: %w[clusterId clusterSlug southWestLat southWestLon northEastLat northEastLon],
        optional_properties: %w[name nameEn regionId regionSlug mainAreaId mainAreaSlug problemCount gradeMin gradeMax gradeHistogramJson coverPhotoUrl warning warningEn guidebookTitle guidebookAuthor guidebookUrl parkingPoiId parkingName parkingGoogleUrl]
      ),
      Layer.new(
        name: "regions",
        geometry_type: "Point",
        required_properties: %w[regionId regionSlug name southWestLat southWestLon northEastLat northEastLon],
        optional_properties: %w[nameEn mainClusterId mainClusterSlug mainClusterSouthWestLat mainClusterSouthWestLon mainClusterNorthEastLat mainClusterNorthEastLon problemCount gradeMin gradeMax gradeHistogramJson coverPhotoUrl warning warningEn guidebookTitle guidebookAuthor guidebookUrl parkingPoiId parkingName parkingGoogleUrl]
      ),
      Layer.new(
        name: "region_hulls",
        geometry_type: "Polygon",
        required_properties: %w[regionId regionSlug southWestLat southWestLon northEastLat northEastLon],
        optional_properties: %w[name nameEn mainClusterId mainClusterSlug mainClusterSouthWestLat mainClusterSouthWestLon mainClusterNorthEastLat mainClusterNorthEastLon problemCount gradeMin gradeMax gradeHistogramJson coverPhotoUrl warning warningEn guidebookTitle guidebookAuthor guidebookUrl parkingPoiId parkingName parkingGoogleUrl]
      ),
      Layer.new(
        name: "walking_paths",
        geometry_type: "LineString/MultiLineString",
        required_properties: %w[walkingPathId slug name],
        optional_properties: %w[nameEn description]
      ),
      Layer.new(
        name: "pois",
        geometry_type: "Point",
        required_properties: %w[poiId poiType name accessAreasJson],
        optional_properties: %w[shortName googleUrl]
      )
    ].freeze

    def self.native_max_zoom
      NATIVE_MAX_ZOOM
    end

    def self.layers
      LAYERS
    end

    def self.layer_names
      layers.map(&:name)
    end

    def self.fetch(layer_name)
      layers.find { |layer| layer.name == layer_name.to_s } || raise(KeyError, "unknown map tile layer: #{layer_name}")
    end

    def self.assert_no_circuit!
      offenders = layers.flat_map { |layer| [ layer.name, *layer.properties ] }.grep(/circuit/i)
      raise ArgumentError, "circuit map tile fields are not allowed: #{offenders.join(', ')}" if offenders.any?

      true
    end
  end
end
