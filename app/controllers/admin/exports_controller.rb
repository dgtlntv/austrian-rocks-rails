class Admin::ExportsController < Admin::BaseController
  def index
  end

  def db
    tempfile = Tempfile.new([ BRAND_CONFIG[:slug], ".db" ])
    AppDbExporter.call(tempfile.path)

    send_file tempfile.path,
      filename: "#{BRAND_CONFIG[:slug]}.db",
      type: "application/x-sqlite3",
      disposition: :attachment
  ensure
    tempfile&.close
  end

  def areas_geojson
    factory = RGeo::GeoJSON::EntityFactory.instance

    area_features = []
    hull_features = []

    Area.published.each do |area|
      result = area.boulders.where(ignore_for_area_hull: false).
        select("st_buffer(st_convexhull(st_collect(polygon::geometry)),0.00007) as hull",
               "st_centroid(st_buffer(st_convexhull(st_collect(polygon::geometry)),0.00007)) as centroid").to_a.first

      next unless result&.hull

      hull = result.hull
      centroid = result.centroid

      hash = {}.with_indifferent_access
      hash[:area_id] = area.id
      hash[:south_west_lat] = area.bounds[:south_west].lat.to_s
      hash[:south_west_lon] = area.bounds[:south_west].lon.to_s
      hash[:north_east_lat] = area.bounds[:north_east].lat.to_s
      hash[:north_east_lon] = area.bounds[:north_east].lon.to_s
      hash.deep_transform_keys! { |key| key.camelize(:lower) }
      hull_features << factory.feature(hull, nil, hash)

      hash = {}.with_indifferent_access
      hash[:name] = area.short_name || area.name
      hash[:area_id] = area.id
      hash[:priority] = area.priority
      hash[:south_west_lat] = area.bounds[:south_west].lat.to_s
      hash[:south_west_lon] = area.bounds[:south_west].lon.to_s
      hash[:north_east_lat] = area.bounds[:north_east].lat.to_s
      hash[:north_east_lon] = area.bounds[:north_east].lon.to_s
      hash.deep_transform_keys! { |key| key.camelize(:lower) }
      area_features << factory.feature(centroid, nil, hash)
    end

    feature_collection = factory.feature_collection(area_features + hull_features)
    geo_json = JSON.pretty_generate(RGeo::GeoJSON.encode(feature_collection))

    send_data geo_json, filename: "areas.geojson", type: "application/geo+json"
  end

  def clusters_geojson
    factory = RGeo::GeoJSON::EntityFactory.instance

    cluster_features = []
    hull_features = []

    Cluster.all.each do |cluster|
      hull = Boulder.where(area_id: cluster.areas.map(&:id)).where(ignore_for_area_hull: false).
        select("st_buffer(st_convexhull(st_collect(polygon::geometry)),0.00007) as hull").to_a.first&.hull

      if hull
        hash = {}.with_indifferent_access
        hash[:cluster_id] = cluster.id
        hash[:name] = cluster.name
        hash.deep_transform_keys! { |key| key.camelize(:lower) }
        hull_features << factory.feature(hull, nil, hash)
      end

      if cluster.sw && cluster.ne && cluster.center
        hash = {}.with_indifferent_access
        hash[:cluster_id] = cluster.id
        hash[:name] = cluster.name
        hash[:south_west_lat] = cluster.sw.lat.to_s
        hash[:south_west_lon] = cluster.sw.lon.to_s
        hash[:north_east_lat] = cluster.ne.lat.to_s
        hash[:north_east_lon] = cluster.ne.lon.to_s
        hash.deep_transform_keys! { |key| key.camelize(:lower) }
        cluster_features << factory.feature(cluster.center, nil, hash)
      end
    end

    feature_collection = factory.feature_collection(cluster_features + hull_features)
    geo_json = JSON.pretty_generate(RGeo::GeoJSON.encode(feature_collection))

    send_data geo_json, filename: "clusters.geojson", type: "application/geo+json"
  end

  def regions_geojson
    factory = RGeo::GeoJSON::EntityFactory.instance

    region_features = []
    hull_features = []

    Region.all.each do |region|
      cluster_ids = region.clusters.pluck(:id)
      area_ids = Area.where(cluster_id: cluster_ids).pluck(:id)

      next if area_ids.empty?

      hull = Boulder.where(area_id: area_ids).where(ignore_for_area_hull: false).
        select("st_buffer(st_convexhull(st_collect(polygon::geometry)),0.00007) as hull").to_a.first&.hull

      if hull
        hash = {}.with_indifferent_access
        hash[:region_id] = region.id
        hash[:name] = region.name
        hash.deep_transform_keys! { |key| key.camelize(:lower) }
        hull_features << factory.feature(hull, nil, hash)
      end

      if region.sw && region.ne && region.center
        hash = {}.with_indifferent_access
        hash[:region_id] = region.id
        hash[:name] = region.name
        hash[:south_west_lat] = region.sw.lat.to_s
        hash[:south_west_lon] = region.sw.lon.to_s
        hash[:north_east_lat] = region.ne.lat.to_s
        hash[:north_east_lon] = region.ne.lon.to_s
        hash.deep_transform_keys! { |key| key.camelize(:lower) }
        region_features << factory.feature(region.center, nil, hash)
      end
    end

    feature_collection = factory.feature_collection(region_features + hull_features)
    geo_json = JSON.pretty_generate(RGeo::GeoJSON.encode(feature_collection))

    send_data geo_json, filename: "regions.geojson", type: "application/geo+json"
  end

  def problems_geojson
    include_boulders = params[:include_boulders] == "true"

    factory = RGeo::GeoJSON::EntityFactory.instance

    problem_features = Problem.with_location.joins(:area).where(area: { published: true }).map do |problem|
      hash = {}.with_indifferent_access
      hash.merge!(problem.slice(:grade, :steepness, :featured, :popularity))
      hash[:id] = problem.id

      name_de = I18n.with_locale(:de) { problem.name_with_fallback }
      name_en = I18n.with_locale(:en) { problem.name_with_fallback }
      hash[:name] = name_de
      hash[:name_en] = (name_en != name_de) ? name_en : ""

      hash.deep_transform_keys! { |key| key.camelize(:lower) }

      factory.feature(problem.location, nil, hash)
    end

    boulder_features = Boulder.where.not(area_id: [ 45, 75, 79, 104, 113 ]).joins(:area).where(area: { published: true }).map do |boulder|
      hash = {}.with_indifferent_access
      hash[:name] = boulder.name if boulder.name.present?
      hash.deep_transform_keys! { |key| key.camelize(:lower) }

      factory.feature(boulder.polygon, nil, hash)
    end

    features = include_boulders ? problem_features + boulder_features : problem_features

    feature_collection = factory.feature_collection(features)
    geo_json = JSON.pretty_generate(RGeo::GeoJSON.encode(feature_collection))

    filename = include_boulders ? "problems.geojson" : "problems-without-boulders.geojson"

    send_data geo_json, filename: filename, type: "application/geo+json"
  end
end
