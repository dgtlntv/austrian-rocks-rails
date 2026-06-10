# frozen_string_literal: true

require "fileutils"
require "json"
require "rgeo/geo_json"
require "map_tiles/configuration"

module MapTiles
  class GeojsonExporter
    attr_reader :configuration, :entity_factory

    def initialize(configuration: Configuration.new)
      @configuration = configuration
      @entity_factory = RGeo::GeoJSON::EntityFactory.instance
    end

    def export
      FileUtils.mkdir_p(configuration.geojson_dir)

      {
        "problems" => write_layer("problems", problem_features),
        "boulders" => write_layer("boulders", boulder_features),
        "areas" => write_layer("areas", area_features),
        "area_hulls" => write_layer("area_hulls", area_hull_features),
        "clusters" => write_layer("clusters", cluster_features),
        "cluster_hulls" => write_layer("cluster_hulls", cluster_hull_features),
        "regions" => write_layer("regions", region_features),
        "region_hulls" => write_layer("region_hulls", region_hull_features),
        "walking_paths" => write_layer("walking_paths", walking_path_features),
        "pois" => write_layer("pois", poi_features)
      }
    end

    private

    def write_layer(layer_name, features)
      path = configuration.geojson_dir.join("#{layer_name}.geojson")
      collection = entity_factory.feature_collection(features)
      encoded = RGeo::GeoJSON.encode(collection)
      path.write(JSON.pretty_generate(encoded))
      path
    end

    def feature(geometry, properties)
      entity_factory.feature(geometry, nil, compact_properties(properties))
    end

    def compact_properties(properties)
      properties.each_with_object({}) do |(key, value), result|
        next if value.nil?
        next if value.respond_to?(:empty?) && value.empty?

        result[key.to_s] = scalar_value(value)
      end
    end

    def scalar_value(value)
      case value
      when BigDecimal
        value.to_f
      else
        value
      end
    end

    def problem_features
      Problem.with_location.joins(:area).where(areas: { published: true }).includes(:area).order(:id).filter_map do |problem|
        area = problem.area
        next if problem.location.blank? || area.blank? || area.slug.blank?

        name = localized_problem_name(problem, :de)
        name_en = localized_problem_name(problem, :en)

        feature(problem.location, {
          problemId: problem.id,
          areaId: area.id,
          areaSlug: area.slug,
          name: name,
          grade: problem_grade(problem),
          steepness: problem.steepness,
          featured: problem.featured?,
          boulderId: problem.boulder_id,
          nameEn: different_label(name, name_en),
          popularity: problem.popularity,
          landing: problem.landing,
          height: problem.height,
          parentProblemId: problem.parent_id
        }.merge(problem_topo_properties(problem)))
      end
    end

    def boulder_features
      Boulder.joins(:area).where(areas: { published: true }).where.not(polygon: nil).includes(:area).order(:id).filter_map do |boulder|
        area = boulder.area
        next if area.blank? || area.slug.blank?

        feature(boulder.polygon, {
          boulderId: boulder.id,
          areaId: area.id,
          areaSlug: area.slug,
          name: boulder.name
        })
      end
    end

    def area_features
      published_areas.filter_map do |area|
        result = hull_result_for_boulders(area.boulders.where(ignore_for_area_hull: false))
        bounds = bounds_for_boulders(area.boulders.where(ignore_for_area_hull: false))
        next if result&.hull.blank? || result&.centroid.blank? || bounds.blank?

        feature(result.centroid, area_properties(area, bounds, include_name: true, include_short_name: true, include_cluster: true))
      end
    end

    def area_hull_features
      published_areas.filter_map do |area|
        hull = hull_for_boulders(area.boulders.where(ignore_for_area_hull: false))
        bounds = bounds_for_boulders(area.boulders.where(ignore_for_area_hull: false))
        next if hull.blank? || bounds.blank?

        feature(hull, area_properties(area, bounds, include_name: true))
      end
    end

    def cluster_features
      published_clusters.filter_map do |cluster|
        area_ids = published_child_areas(cluster).pluck(:id)
        result = hull_result_for_area_ids(area_ids)
        bounds = explicit_or_boulder_bounds(cluster, area_ids)
        point = cluster.center || result&.centroid
        next if point.blank? || bounds.blank?

        feature(point, cluster_properties(cluster, bounds, include_name: true))
      end
    end

    def cluster_hull_features
      published_clusters.filter_map do |cluster|
        area_ids = published_child_areas(cluster).pluck(:id)
        hull = hull_for_area_ids(area_ids)
        bounds = explicit_or_boulder_bounds(cluster, area_ids)
        next if hull.blank? || bounds.blank?

        feature(hull, cluster_properties(cluster, bounds, include_name: true))
      end
    end

    def region_features
      published_regions.filter_map do |region|
        area_ids = published_descendant_areas(region).pluck(:id)
        result = hull_result_for_area_ids(area_ids)
        bounds = explicit_or_boulder_bounds(region, area_ids)
        point = region.center || result&.centroid
        next if point.blank? || bounds.blank?

        feature(point, region_properties(region, bounds, include_name: true))
      end
    end

    def region_hull_features
      published_regions.filter_map do |region|
        area_ids = published_descendant_areas(region).pluck(:id)
        hull = hull_for_area_ids(area_ids)
        bounds = explicit_or_boulder_bounds(region, area_ids)
        next if hull.blank? || bounds.blank?

        feature(hull, region_properties(region, bounds, include_name: true))
      end
    end

    def walking_path_features
      WalkingPath.where(published: true).where.not(geometry: nil).order(:id).map do |walking_path|
        feature(walking_path.geometry, {
          walkingPathId: walking_path.id,
          slug: walking_path.slug,
          name: display_label(walking_path, :label, :slug, fallback_prefix: "Walking path"),
          description: walking_path.description
        })
      end
    end

    def poi_features
      Poi.where.not(location: nil).includes(poi_routes: :area).order(:id).map do |poi|
        feature(poi.location, {
          poiId: poi.id,
          poiType: poi.poi_type,
          name: display_label(poi, :name, :short_name, fallback_prefix: "POI"),
          accessAreasJson: JSON.generate(access_area_entries(poi)),
          shortName: poi.short_name,
          googleUrl: poi.google_url
        })
      end
    end

    def access_area_entries(poi)
      poi.poi_routes.sort_by(&:id).filter_map do |route|
        area = route.area
        next if area.blank? || !area.published? || area.slug.blank?

        {
          areaId: area.id,
          areaSlug: area.slug,
          transport: route.transport,
          distance: route.distance,
          minutes: route.distance_in_minutes
        }
      end
    end

    def published_areas
      Area.published.includes(:cluster, :boulders).order(:id)
    end

    def published_clusters
      Cluster.published.includes(:region).order(:id)
    end

    def published_regions
      Region.published.order(:id)
    end

    def published_child_areas(cluster)
      Area.published.where(cluster_id: cluster.id)
    end

    def published_descendant_areas(region)
      Area.published.joins(:cluster).where(clusters: { region_id: region.id, published: true })
    end

    def area_properties(area, bounds, include_name: false, include_short_name: false, include_cluster: false)
      cluster = area.cluster if include_cluster
      area_ids = [ area.id ]

      {
        areaId: area.id,
        areaSlug: area.slug,
        name: include_name ? display_label(area, :name, :slug, fallback_prefix: "Area") : nil,
        priority: area.priority,
        shortName: include_short_name ? area.short_name : nil,
        clusterId: cluster&.id,
        clusterSlug: cluster&.slug
      }.merge(bounds_properties(bounds)).
        merge(aggregate_properties(area_ids)).
        merge(card_properties(area))
    end

    def cluster_properties(cluster, bounds, include_name: false)
      region = cluster.region
      main_area = Area.find_by(id: cluster.main_area_id) if cluster.main_area_id.present?
      area_ids = published_child_areas(cluster).pluck(:id)

      {
        clusterId: cluster.id,
        clusterSlug: cluster.slug,
        name: include_name ? display_label(cluster, :name, :slug, fallback_prefix: "Cluster") : nil,
        regionId: region&.id,
        regionSlug: region&.slug,
        mainAreaId: main_area&.id,
        mainAreaSlug: main_area&.slug
      }.merge(bounds_properties(bounds)).
        merge(aggregate_properties(area_ids)).
        merge(card_properties(cluster))
    end

    def region_properties(region, bounds, include_name: false)
      main_cluster = Cluster.find_by(id: region.main_cluster_id) if region.main_cluster_id.present?
      area_ids = published_descendant_areas(region).pluck(:id)

      {
        regionId: region.id,
        regionSlug: region.slug,
        name: include_name ? display_label(region, :name, :slug, fallback_prefix: "Region") : nil,
        mainClusterId: main_cluster&.id,
        mainClusterSlug: main_cluster&.slug
      }.merge(bounds_properties(bounds)).
        merge(aggregate_properties(area_ids)).
        merge(card_properties(region)).
        merge(main_cluster_bounds_properties(main_cluster))
    end

    # Resolve card metadata from the closest climbing entity first, then walk up the
    # area -> cluster -> region hierarchy. The exported scalar values are the contract
    # seam shared by web and native clients, so the cascade is resolved here once.
    def effective_card_attributes(record)
      records = card_cascade_records(record)

      {
        warning_de: first_present(records, :warning_de),
        warning_en: first_present(records, :warning_en),
        guidebook: first_present(records, :guidebook),
        parking_poi: first_present(records, :parking_poi)
      }
    end

    def card_cascade_records(record)
      case record
      when Area
        [ record, record.cluster, record.cluster&.region ].compact
      when Cluster
        [ record, record.region ].compact
      when Region
        [ record ]
      else
        [ record ]
      end
    end

    def first_present(records, attribute)
      records.each do |record|
        value = record.public_send(attribute)
        return value if value.present?
      end

      nil
    end

    def aggregate_properties(area_ids)
      grade_min, grade_max = grade_range_for_area_ids(area_ids)

      {
        problemCount: problem_count_for_area_ids(area_ids),
        gradeMin: grade_min,
        gradeMax: grade_max,
        gradeHistogramJson: grade_histogram_json_for_area_ids(area_ids)
      }
    end

    def problem_count_for_area_ids(area_ids)
      Problem.joins(:area).where(area_id: area_ids, areas: { published: true }).count
    end

    def grade_range_for_area_ids(area_ids)
      return if area_ids.blank?

      grade_indexes = Problem.joins(:area).
        where(area_id: area_ids, areas: { published: true }).
        where.not(grade: [ nil, "" ]).
        distinct.
        pluck(:grade).
        filter_map { |grade| Problem::GRADE_VALUES.index(grade) }
      return if grade_indexes.blank?

      [ Problem::GRADE_VALUES.fetch(grade_indexes.min), Problem::GRADE_VALUES.fetch(grade_indexes.max) ]
    end

    # Problem counts per letter grade ("6a" buckets "6a", "6a/+" and "6a+"),
    # serialized as a sparse JSON object because tile properties are scalars.
    def grade_histogram_json_for_area_ids(area_ids)
      return if area_ids.blank?

      counts_by_grade = Problem.joins(:area).
        where(area_id: area_ids, areas: { published: true }).
        where.not(grade: [ nil, "" ]).
        group(:grade).
        count

      buckets = Hash.new(0)
      counts_by_grade.each do |grade, count|
        bucket = grade[0, 2]
        buckets[bucket] += count if bucket.match?(/\A[1-9][abc]\z/)
      end
      return if buckets.empty?

      JSON.generate(buckets.sort.to_h)
    end

    def card_properties(record)
      attributes = effective_card_attributes(record)
      guidebook = attributes.fetch(:guidebook)
      parking_poi = attributes.fetch(:parking_poi)
      warning_de = attributes.fetch(:warning_de)
      warning_en = attributes.fetch(:warning_en)

      {
        coverPhotoUrl: cover_photo_url(record),
        warning: warning_de,
        warningEn: different_label(warning_de, warning_en),
        guidebookTitle: guidebook&.title,
        guidebookAuthor: guidebook&.author,
        guidebookUrl: guidebook&.url,
        parkingPoiId: parking_poi&.id,
        parkingName: parking_poi&.name,
        parkingGoogleUrl: parking_poi&.google_url
      }
    end

    def problem_topo_properties(problem)
      line = problem.lines.published.with_coordinates.includes(topo: { photo_attachment: :blob }).first
      return {} if line.blank? || line.topo.blank? || !line.topo.photo.attached?

      {
        topoPhotoUrl: cdn_variant_url(line.topo.photo.variant(:medium)),
        lineCoordinatesJson: JSON.generate(line.coordinates)
      }
    end

    def cover_photo_url(record)
      cover = effective_cover_attachment(record)
      return unless cover&.attached?

      cdn_variant_url(cover.variant(:medium))
    end

    def cdn_variant_url(variant)
      Rails.application.routes.url_helpers.cdn_image_url(
        variant,
        expires_in: nil,
        host: Rails.application.config.asset_host.presence || "http://localhost:3000"
      )
    end

    def effective_cover_attachment(record)
      return record.cover if record.respond_to?(:cover) && record.cover.attached?

      case record
      when Cluster
        main_area = Area.find_by(id: record.main_area_id) if record.main_area_id.present?
        effective_cover_attachment(main_area) if main_area.present?
      when Region
        main_cluster = Cluster.find_by(id: record.main_cluster_id) if record.main_cluster_id.present?
        effective_cover_attachment(main_cluster) if main_cluster.present?
      end
    end

    def main_cluster_bounds_properties(main_cluster)
      return {} if main_cluster.blank?

      area_ids = published_child_areas(main_cluster).pluck(:id)
      bounds = explicit_or_boulder_bounds(main_cluster, area_ids)
      return {} if bounds.blank?

      {
        mainClusterSouthWestLat: bounds[:south_west_lat],
        mainClusterSouthWestLon: bounds[:south_west_lon],
        mainClusterNorthEastLat: bounds[:north_east_lat],
        mainClusterNorthEastLon: bounds[:north_east_lon]
      }
    end

    def bounds_properties(bounds)
      {
        southWestLat: bounds[:south_west_lat],
        southWestLon: bounds[:south_west_lon],
        northEastLat: bounds[:north_east_lat],
        northEastLon: bounds[:north_east_lon]
      }
    end

    def hull_for_area_ids(area_ids)
      hull_result_for_area_ids(area_ids)&.hull
    end

    def hull_result_for_area_ids(area_ids)
      return if area_ids.blank?

      hull_result_for_boulders(Boulder.where(area_id: area_ids).where(ignore_for_area_hull: false))
    end

    def hull_for_boulders(boulders)
      hull_result_for_boulders(boulders)&.hull
    end

    def hull_result_for_boulders(boulders)
      hull_sql = "st_buffer(st_convexhull(st_collect(polygon::geometry)), 0.00007)"
      boulders.where.not(polygon: nil).
        select("#{hull_sql} AS hull", "st_centroid(#{hull_sql}) AS centroid").
        to_a.first
    end

    def bounds_for_boulders(boulders)
      result = boulders.where.not(polygon: nil).
        select(
          "st_ymin(st_extent(polygon::geometry)) AS south_west_lat",
          "st_xmin(st_extent(polygon::geometry)) AS south_west_lon",
          "st_ymax(st_extent(polygon::geometry)) AS north_east_lat",
          "st_xmax(st_extent(polygon::geometry)) AS north_east_lon"
        ).to_a.first

      return if result.blank? || result.south_west_lat.blank?

      {
        south_west_lat: result.south_west_lat.to_f,
        south_west_lon: result.south_west_lon.to_f,
        north_east_lat: result.north_east_lat.to_f,
        north_east_lon: result.north_east_lon.to_f
      }
    end

    def explicit_or_boulder_bounds(record, area_ids)
      if record.sw.present? && record.ne.present?
        {
          south_west_lat: record.sw.lat,
          south_west_lon: record.sw.lon,
          north_east_lat: record.ne.lat,
          north_east_lon: record.ne.lon
        }
      else
        bounds_for_boulders(Boulder.where(area_id: area_ids).where(ignore_for_area_hull: false))
      end
    end

    def localized_problem_name(problem, locale)
      I18n.with_locale(locale) { problem.name_with_fallback }
    end

    def problem_grade(problem)
      problem.grade.presence || "unknown"
    end

    def display_label(record, *attributes, fallback_prefix:)
      attributes.each do |attribute|
        value = record.public_send(attribute)
        return value if value.present?
      end

      "#{fallback_prefix} #{record.id}"
    end

    def different_label(default_label, localized_label)
      localized_label if localized_label.present? && localized_label != default_label
    end
  end
end
