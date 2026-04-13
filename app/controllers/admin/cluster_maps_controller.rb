class Admin::ClusterMapsController < Admin::BaseController
  def show
    cluster = Cluster.find(params[:cluster_id])
    factory = RGeo::GeoJSON::EntityFactory.instance

    features = []

    # Create rectangle feature from cluster bounds
    if cluster.sw && cluster.ne
      # Create a rectangle polygon from SW and NE corners
      rectangle = FACTORY.polygon(
        FACTORY.line_string([
          FACTORY.point(cluster.sw.lon, cluster.sw.lat),  # SW corner
          FACTORY.point(cluster.sw.lon, cluster.ne.lat),  # NW corner
          FACTORY.point(cluster.ne.lon, cluster.ne.lat),  # NE corner
          FACTORY.point(cluster.ne.lon, cluster.sw.lat),  # SE corner
          FACTORY.point(cluster.sw.lon, cluster.sw.lat)   # Close (back to SW)
        ])
      )

      hash = {}.with_indifferent_access
      hash[:cluster_id] = cluster.id
      hash[:name] = cluster.name
      hash[:updated_at] = cluster.updated_at
      hash.deep_transform_keys! { |key| key.camelize(:lower) }

      features << factory.feature(rectangle, nil, hash)
    end

    feature_collection = factory.feature_collection(features)
    json = JSON.pretty_generate(RGeo::GeoJSON.encode(feature_collection))

    respond_to do |format|
      format.geojson do
        if params[:download].present?
          send_data json, filename: "cluster-#{cluster.id}-#{cluster.name.parameterize}.geojson", type: "application/geo+json"
        else
          render json: json
        end
      end
    end
  end
end
