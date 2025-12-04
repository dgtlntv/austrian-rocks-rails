require "rgeo/geo_json"

namespace :mapbox do
  task areas: :environment do
    puts "exporting areas"

    factory = RGeo::GeoJSON::EntityFactory.instance

    area_features = []
    hull_features = []

    Area.published.each do |area|
      result = area.boulders.where(ignore_for_area_hull: false).
        select("st_buffer(st_convexhull(st_collect(polygon::geometry)),0.00007) as hull",
               "st_centroid(st_buffer(st_convexhull(st_collect(polygon::geometry)),0.00007)) as centroid").to_a.first
      
      # Skip areas with no boulders
      next unless result&.hull
      
      hull = result.hull
      centroid = result.centroid

      hash = {}.with_indifferent_access
      hash[:area_id] = area.id
      # we store lat/lon as strings to make it easier to edit the geojson in tools like JOSM
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
      # we store lat/lon as strings to make it easier to edit the geojson in tools like JOSM
      hash[:south_west_lat] = area.bounds[:south_west].lat.to_s
      hash[:south_west_lon] = area.bounds[:south_west].lon.to_s
      hash[:north_east_lat] = area.bounds[:north_east].lat.to_s
      hash[:north_east_lon] = area.bounds[:north_east].lon.to_s
      hash.deep_transform_keys! { |key| key.camelize(:lower) }
      area_features << factory.feature(centroid, nil, hash)
    end

    feature_collection = factory.feature_collection(
      area_features + hull_features
    )

    geo_json = JSON.pretty_generate(RGeo::GeoJSON.encode(feature_collection))

    file_name = Rails.root.join("..", "#{BRAND_CONFIG[:slug]}-maps", "mapbox", "areas.geojson")

    File.open(file_name, "w") do |f|
      f.write(geo_json)
    end

    puts "exported areas.geojson".green
  end

  task regions: :environment do
    puts "exporting regions"

    factory = RGeo::GeoJSON::EntityFactory.instance

    region_features = []
    hull_features = []

    Region.all.each do |region|
      # Get all boulders from clusters within this region
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

    feature_collection = factory.feature_collection(
      region_features + hull_features
    )

    geo_json = JSON.pretty_generate(RGeo::GeoJSON.encode(feature_collection))

    file_name = Rails.root.join("..", "#{BRAND_CONFIG[:slug]}-maps", "mapbox", "regions.geojson")

    File.open(file_name, "w") do |f|
      f.write(geo_json)
    end

    puts "exported regions.geojson".green
  end

  task clusters: :environment do
    puts "exporting clusters"

    factory = RGeo::GeoJSON::EntityFactory.instance

    cluster_features = []
    hull_features = []

    Cluster.all.each do |cluster|
      hull = Boulder.where(area_id: cluster.areas.map(&:id)).where(ignore_for_area_hull: false).
        select("st_buffer(st_convexhull(st_collect(polygon::geometry)),0.00007) as hull").to_a.first.hull

      hash = {}.with_indifferent_access
      hash[:cluster_id] = cluster.id
      hash[:name] = cluster.name

      hash.deep_transform_keys! { |key| key.camelize(:lower) }
      hull_features << factory.feature(hull, nil, hash)

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

    feature_collection = factory.feature_collection(
      cluster_features + hull_features
    )

    geo_json = JSON.pretty_generate(RGeo::GeoJSON.encode(feature_collection))

    file_name = Rails.root.join("..", "#{BRAND_CONFIG[:slug]}-maps", "mapbox", "clusters.geojson")

    File.open(file_name, "w") do |f|
      f.write(geo_json)
    end

    puts "exported clusters.geojson".green
  end

  task problems: :environment do
    puts "exporting problems"

    raise "please specify a value for include_boulders (true or false). Reminder: don't include boulders when exporting to #{BRAND_CONFIG[:slug]}-data" unless ENV["include_boulders"].present?
    include_boulders = ENV["include_boulders"] == "true"

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

    # Extract boulders alongside problems to ensure we always upload both at the same time to mapbox
    boulder_features = Boulder.where.not(area_id: [ 45, 75, 79, 104, 113 ]).joins(:area).where(area: { published: true }).map do |boulder|
      hash = {}.with_indifferent_access
      hash[:name] = boulder.name if boulder.name.present?
      hash.deep_transform_keys! { |key| key.camelize(:lower) }

      factory.feature(boulder.polygon, nil, hash)
    end

    if include_boulders
      features = problem_features + boulder_features
    else
      features = problem_features
    end

    feature_collection = factory.feature_collection(
      features
    )

    geo_json = RGeo::GeoJSON.encode(feature_collection)

    File.open(Rails.root.join("..", "#{BRAND_CONFIG[:slug]}-maps", "mapbox", "problems#{"-without-boulders" if !include_boulders}.geojson"), "w") do |f|
      f.write(JSON.pretty_generate(geo_json))
    end

    puts "exported problems.geojson".green
  end


  # TODO: Revamp the pois task once we migrate to the new POI data model (split pois and poi routes)

  # task pois: :environment do
  #   puts "exporting pois"

  #   factory = RGeo::GeoJSON::EntityFactory.instance

  #   poi_features = Poi.all.reject{|poi| poi.id.in?([10,26]) }.uniq(&:description).map do |poi|
  #     hash = {}.with_indifferent_access
  #     hash[:type] = "parking"
  #     hash[:name] = poi.description
  #     hash[:short_name] = poi.subtitle
  #     hash[:google_url] = poi.google_url
  #     hash.deep_transform_keys! { |key| key.camelize(:lower) }

  #     factory.feature(poi.location, nil, hash)
  #   end

  #   feature_collection = factory.feature_collection(
  #     poi_features
  #   )

  #   geo_json = JSON.pretty_generate(RGeo::GeoJSON.encode(feature_collection))

  #   file_name = Rails.root.join("..", "#{BRAND_CONFIG[:slug]}-maps", "mapbox", "pois.geojson")

  #   raise "file already exists" if File.exist?(file_name)

  #   File.open(file_name,"w") do |f|
  #     f.write(geo_json)
  #   end

  #   puts "exported pois.geojson".green
  # end
end
