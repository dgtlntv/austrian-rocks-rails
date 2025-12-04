class Admin::AreasController < Admin::BaseController
  def index
    sort = params[:sort] == "id" ? :id : :name
    @areas = Area.order(sort)
  end

  def new
    @area = Area.new
  end

  def create
    area = Area.new
    area.assign_attributes(area_params)
    area.tags = params[:area][:joined_tags].to_s.split(",").reject(&:blank?)

    if cover = params[:area][:cover]
      area.cover = params[:area][:cover]
    end

    area.save!

    flash[:notice] = "Area created"
    redirect_to [:admin, area]
  end

  def edit
    set_area
  end

  def show
    set_area
    redirect_to admin_area_problems_path(@area)
  end

  def update
    set_area

    @area.assign_attributes(area_params)
    @area.tags = params[:area][:joined_tags].split(",")

    if cover = params[:area][:cover]
      @area.cover = params[:area][:cover]
    end

    if @area.save
      flash[:notice] = "Area updated"
      redirect_to edit_admin_area_path(@area)
    else
      flash[:error] = @area.errors.full_messages.join("; ")
      render "edit", status: :unprocessable_entity
    end
  end

  def export
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

    respond_to do |format|
      format.geojson do
        send_data geo_json, filename: "areas.geojson", type: "application/geo+json"
      end
    end
  end

  private
  def area_params
    params.require(:area).
      permit(:name, :slug, :published, :priority, :short_name, :description_fr, :description_en, :warning_fr, :warning_en, :cluster_id)
  end

  def set_area
    @area = Area.find_by(slug: params[:slug])
  end
end
