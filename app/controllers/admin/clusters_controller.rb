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

  private

  def cluster_params
    params.require(:cluster).permit(:name, :main_area_id)
  end

  def set_cluster
    @cluster = Cluster.find(params[:id])
  end
end
