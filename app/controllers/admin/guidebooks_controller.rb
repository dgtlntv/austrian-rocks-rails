class Admin::GuidebooksController < Admin::BaseController
  def index
    @guidebooks = Guidebook.order(:title)
  end

  def new
    @guidebook = Guidebook.new
  end

  def create
    guidebook = Guidebook.new(guidebook_params)

    if guidebook.save
      flash[:notice] = "Guidebook created"
      redirect_to edit_admin_guidebook_path(guidebook)
    else
      flash[:error] = guidebook.errors.full_messages.join("; ")
      @guidebook = guidebook
      render "new", status: :unprocessable_entity
    end
  end

  def edit
    set_guidebook
  end

  def update
    set_guidebook

    if @guidebook.update(guidebook_params)
      flash[:notice] = "Guidebook updated"
      redirect_to edit_admin_guidebook_path(@guidebook)
    else
      flash[:error] = @guidebook.errors.full_messages.join("; ")
      render "edit", status: :unprocessable_entity
    end
  end

  def destroy
    set_guidebook
    @guidebook.destroy
    flash[:notice] = "Guidebook deleted"
    redirect_to admin_guidebooks_path
  end

  private

  def guidebook_params
    params.require(:guidebook).permit(:title, :author, :url)
  end

  def set_guidebook
    @guidebook = Guidebook.find(params[:id])
  end
end
