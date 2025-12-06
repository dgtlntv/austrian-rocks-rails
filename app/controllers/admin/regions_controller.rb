class Admin::RegionsController < Admin::BaseController
  def index
    @regions = Region.order(:id)
  end

  def new
    @region = Region.new
  end

  def create
    region = Region.new
    region.assign_attributes(region_params)
    region.tags = params[:region][:joined_tags].to_s.split(",").reject(&:blank?)

    if cover = params[:region][:cover]
      region.cover = params[:region][:cover]
    end

    if region.save
      flash[:notice] = "Region created"
      redirect_to edit_admin_region_path(region)
    else
      flash[:error] = region.errors.full_messages.join("; ")
      @region = region
      render "new", status: :unprocessable_entity
    end
  end

  def edit
    set_region
  end

  def update
    set_region

    @region.assign_attributes(region_params)
    @region.tags = params[:region][:joined_tags].to_s.split(",").reject(&:blank?)

    if cover = params[:region][:cover]
      @region.cover = params[:region][:cover]
    end

    if @region.save
      flash[:notice] = "Region updated"
      redirect_to edit_admin_region_path(@region)
    else
      flash[:error] = @region.errors.full_messages.join("; ")
      render "edit", status: :unprocessable_entity
    end
  end

  def destroy
    set_region
    @region.destroy
    flash[:notice] = "Region deleted"
    redirect_to admin_regions_path
  end

  def export
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

    respond_to do |format|
      format.geojson do
        send_data geo_json, filename: "regions.geojson", type: "application/geo+json"
      end
    end
  end

  private

  def region_params
    params.require(:region).permit(:name, :slug, :published, :main_cluster_id)
  end

  def set_region
    # Try to find by slug first, fall back to ID
    @region = Region.find_by(slug: params[:id]) || Region.find(params[:id])
  end
end
