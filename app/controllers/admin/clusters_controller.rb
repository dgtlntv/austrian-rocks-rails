class Admin::ClustersController < Admin::BaseController
  def index
    @clusters = Cluster.order(:id)
  end

  def new
    @cluster = Cluster.new
  end

  def create
    cluster = Cluster.new(cluster_params)

    if cluster.save
      flash[:notice] = "Cluster created"
      redirect_to edit_admin_cluster_path(cluster)
    else
      flash[:error] = cluster.errors.full_messages.join("; ")
      @cluster = cluster
      render "new", status: :unprocessable_entity
    end
  end

  def edit
    set_cluster
  end

  def update
    set_cluster

    if @cluster.update(cluster_params)
      flash[:notice] = "Cluster updated"
      redirect_to edit_admin_cluster_path(@cluster)
    else
      flash[:error] = @cluster.errors.full_messages.join("; ")
      render "edit", status: :unprocessable_entity
    end
  end

  def destroy
    set_cluster
    @cluster.destroy
    flash[:notice] = "Cluster deleted"
    redirect_to admin_clusters_path
  end

  def export
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

    feature_collection = factory.feature_collection(
      cluster_features + hull_features
    )

    geo_json = JSON.pretty_generate(RGeo::GeoJSON.encode(feature_collection))

    respond_to do |format|
      format.geojson do
        send_data geo_json, filename: "clusters.geojson", type: "application/geo+json"
      end
    end
  end

  private

  def cluster_params
    params.require(:cluster).permit(:name, :main_area_id, :region_id)
  end

  def set_cluster
    @cluster = Cluster.find(params[:id])
  end
end
