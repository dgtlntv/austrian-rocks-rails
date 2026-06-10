class Admin::RegionsController < Admin::BaseController
  def index
    @regions = Region.order(:name)
    @orphan_clusters = Cluster.where(region_id: nil).order(:name)
    @orphan_areas = Area.where(cluster_id: nil).order(:name)
  end

  def show
    set_region
    @clusters = @region.clusters.order(:name)
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

  private

  def region_params
    params.require(:region).permit(:name, :slug, :published, :main_cluster_id, :warning_de, :warning_en, :guidebook_id, :parking_poi_id)
  end

  def set_region
    # Try to find by slug first, fall back to ID
    @region = Region.find_by(slug: params[:id]) || Region.find(params[:id])
  end
end
