class Admin::RegionsController < Admin::BaseController
  def index
    @regions = Region.order(:id)
  end

  def new
    @region = Region.new
  end

  def create
    region = Region.new(region_params)

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

    if @region.update(region_params)
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
    params.require(:region).permit(:name, :main_cluster_id)
  end

  def set_region
    @region = Region.find(params[:id])
  end
end
