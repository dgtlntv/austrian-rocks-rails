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
        })
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

        feature(result.centroid, area_properties(area, bounds, include_name: true, include_cluster: true))
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

    def area_properties(area, bounds, include_name: false, include_cluster: false)
      cluster = area.cluster if include_cluster
      {
        areaId: area.id,
        areaSlug: area.slug,
        name: include_name ? display_label(area, :name, :slug, fallback_prefix: "Area") : nil,
        priority: area.priority,
        shortName: area.short_name,
        clusterId: cluster&.id,
        clusterSlug: cluster&.slug
      }.merge(bounds_properties(bounds))
    end

    def cluster_properties(cluster, bounds, include_name: false)
      region = cluster.region
      main_area = Area.find_by(id: cluster.main_area_id) if cluster.main_area_id.present?

      {
        clusterId: cluster.id,
        clusterSlug: cluster.slug,
        name: include_name ? display_label(cluster, :name, :slug, fallback_prefix: "Cluster") : nil,
        regionId: region&.id,
        regionSlug: region&.slug,
        mainAreaId: main_area&.id,
        mainAreaSlug: main_area&.slug
      }.merge(bounds_properties(bounds))
    end

    def region_properties(region, bounds, include_name: false)
      main_cluster = Cluster.find_by(id: region.main_cluster_id) if region.main_cluster_id.present?

      {
        regionId: region.id,
        regionSlug: region.slug,
        name: include_name ? display_label(region, :name, :slug, fallback_prefix: "Region") : nil,
        mainClusterId: main_cluster&.id,
        mainClusterSlug: main_cluster&.slug
      }.merge(bounds_properties(bounds))
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
