class Admin::ClustersController < Admin::BaseController
  def index
    @clusters = Cluster.order(:name)
  end

  def show
    set_cluster
    @areas = @cluster.areas.order(:name)
  end

  def new
    @cluster = Cluster.new
  end

  def create
    cluster = Cluster.new
    cluster.assign_attributes(cluster_params)
    cluster.tags = params[:cluster][:joined_tags].to_s.split(",").reject(&:blank?)

    if cover = params[:cluster][:cover]
      cluster.cover = params[:cluster][:cover]
    end

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

    @cluster.assign_attributes(cluster_params)
    @cluster.tags = params[:cluster][:joined_tags].to_s.split(",").reject(&:blank?)

    if cover = params[:cluster][:cover]
      @cluster.cover = params[:cluster][:cover]
    end

    if @cluster.save
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

  private

  def cluster_params
    params.require(:cluster).permit(:name, :slug, :published, :main_area_id, :region_id, :warning_de, :warning_en, :guidebook_id, :parking_poi_id)
  end

  def set_cluster
    # Try to find by slug first, fall back to ID
    @cluster = Cluster.find_by(slug: params[:id]) || Cluster.find(params[:id])
  end
end
