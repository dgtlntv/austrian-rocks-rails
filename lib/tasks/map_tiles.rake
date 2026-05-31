require "rgeo/geo_json"

namespace :map_tiles do
  desc "Export Austrian Rocks map overlay layers as GeoJSON files for Tippecanoe/PMTiles"
  task geojson: :environment do
    output_dir = Rails.root.join("tmp", "map_tiles")
    FileUtils.mkdir_p(output_dir)

    factory = RGeo::GeoJSON::EntityFactory.instance

    write_geojson = ->(name, features) do
      path = output_dir.join("#{name}.geojson")
      collection = factory.feature_collection(features.compact)
      File.write(path, JSON.pretty_generate(RGeo::GeoJSON.encode(collection)))
      puts "exported #{path} (#{features.compact.size} features)"
    end

    problem_features = Problem.with_location.joins(:area).where(area: { published: true }).find_each.map do |problem|
      name_de = I18n.with_locale(:de) { problem.name_with_fallback }
      name_en = I18n.with_locale(:en) { problem.name_with_fallback }

      properties = {
        id: problem.id,
        area_id: problem.area_id,
        name: name_de,
        name_en: (name_en != name_de ? name_en : nil),
        grade: problem.grade,
        steepness: problem.steepness,
        featured: problem.featured,
        popularity: problem.popularity,
        ascents: problem.ascents,
        has_line: problem.has_line
      }.compact.with_indifferent_access.deep_transform_keys { |key| key.camelize(:lower) }

      factory.feature(problem.location, nil, properties)
    end

    boulder_features = Boulder.joins(:area).where(area: { published: true }).where.not(polygon: nil).find_each.map do |boulder|
      properties = {
        id: boulder.id,
        area_id: boulder.area_id,
        name: boulder.name
      }.compact.with_indifferent_access.deep_transform_keys { |key| key.camelize(:lower) }

      factory.feature(boulder.polygon, nil, properties)
    end

    area_point_features = []
    area_hull_features = []

    Area.published.find_each do |area|
      result = area.boulders.where(ignore_for_area_hull: false).
        select("st_buffer(st_convexhull(st_collect(polygon::geometry)),0.00007) as hull", "st_centroid(st_buffer(st_convexhull(st_collect(polygon::geometry)),0.00007)) as centroid").to_a.first

      next unless result&.hull && result&.centroid

      bounds = area.bounds
      properties = {
        id: area.id,
        area_id: area.id,
        name: area.short_name || area.name,
        slug: area.slug,
        priority: area.priority,
        south_west_lat: bounds[:south_west]&.lat,
        south_west_lon: bounds[:south_west]&.lon,
        north_east_lat: bounds[:north_east]&.lat,
        north_east_lon: bounds[:north_east]&.lon,
        problems_count: area.problems.with_location.count
      }.compact.with_indifferent_access.deep_transform_keys { |key| key.camelize(:lower) }

      area_point_features << factory.feature(result.centroid, nil, properties)
      area_hull_features << factory.feature(result.hull, nil, properties)
    end

    cluster_point_features = []
    cluster_hull_features = []

    Cluster.where(published: true).find_each do |cluster|
      properties = {
        id: cluster.id,
        cluster_id: cluster.id,
        name: cluster.name,
        slug: cluster.slug
      }.compact.with_indifferent_access.deep_transform_keys { |key| key.camelize(:lower) }

      cluster_point_features << factory.feature(cluster.center, nil, properties) if cluster.center

      area_ids = cluster.areas.published.pluck(:id)
      next if area_ids.empty?

      hull = Boulder.where(area_id: area_ids, ignore_for_area_hull: false).
        select("st_buffer(st_convexhull(st_collect(polygon::geometry)),0.00007) as hull").to_a.first&.hull
      cluster_hull_features << factory.feature(hull, nil, properties) if hull
    end

    region_point_features = []
    region_hull_features = []

    Region.where(published: true).find_each do |region|
      properties = {
        id: region.id,
        region_id: region.id,
        name: region.name,
        slug: region.slug
      }.compact.with_indifferent_access.deep_transform_keys { |key| key.camelize(:lower) }

      region_point_features << factory.feature(region.center, nil, properties) if region.center

      area_ids = Area.published.where(cluster_id: region.clusters.select(:id)).pluck(:id)
      next if area_ids.empty?

      hull = Boulder.where(area_id: area_ids, ignore_for_area_hull: false).
        select("st_buffer(st_convexhull(st_collect(polygon::geometry)),0.00007) as hull").to_a.first&.hull
      region_hull_features << factory.feature(hull, nil, properties) if hull
    end

    poi_features = Poi.where.not(location: nil).find_each.map do |poi|
      properties = {
        id: poi.id,
        name: poi.name,
        short_name: poi.short_name,
        type: poi.poi_type,
        google_url: poi.google_url
      }.compact.with_indifferent_access.deep_transform_keys { |key| key.camelize(:lower) }

      factory.feature(poi.location, nil, properties)
    end

    write_geojson.call("problems", problem_features)
    write_geojson.call("boulders", boulder_features)
    write_geojson.call("areas", area_point_features)
    write_geojson.call("area_hulls", area_hull_features)
    write_geojson.call("clusters", cluster_point_features)
    write_geojson.call("cluster_hulls", cluster_hull_features)
    write_geojson.call("regions", region_point_features)
    write_geojson.call("region_hulls", region_hull_features)
    write_geojson.call("pois", poi_features)
  end
end
