class Admin::WalkingPathsController < Admin::BaseController
  MAX_GEOJSON_BYTES = 1.megabyte

  before_action :set_walking_path, only: [ :edit, :update, :destroy, :publish, :unpublish ]
  before_action :set_grouping_options, only: [ :new, :create, :edit, :update, :publish ]

  def index
    @walking_paths = WalkingPath.includes(:areas, :clusters).order(:id)
  end

  def new
    @walking_path = WalkingPath.new
  end

  def create
    @walking_path = WalkingPath.new

    if persist_walking_path
      flash[:notice] = "Walking path created"
      redirect_to edit_admin_walking_path_path(@walking_path)
    else
      render_form_error("new")
    end
  end

  def edit
  end

  def update
    if persist_walking_path
      flash[:notice] = "Walking path updated"
      redirect_to edit_admin_walking_path_path(@walking_path)
    else
      render_form_error("edit")
    end
  end

  def destroy
    @walking_path.destroy

    flash[:notice] = "Walking path deleted"
    redirect_to admin_walking_paths_path
  end

  def publish
    if @walking_path.update(published: true)
      flash[:notice] = "Walking path published"
      redirect_to edit_admin_walking_path_path(@walking_path)
    else
      render_form_error("edit")
    end
  end

  def unpublish
    @walking_path.update(published: false)

    flash[:notice] = "Walking path unpublished"
    redirect_to edit_admin_walking_path_path(@walking_path)
  end

  private

  def persist_walking_path
    permitted = walking_path_params
    geojson_text = permitted.delete(:geojson_text)
    geojson_file = permitted.delete(:geojson_file)
    saved = false

    ActiveRecord::Base.transaction do
      @walking_path.assign_attributes(permitted)

      unless apply_geojson_input(geojson_text, geojson_file)
        raise ActiveRecord::Rollback
      end

      saved = @walking_path.save
      raise ActiveRecord::Rollback unless saved
    end

    saved
  end

  def apply_geojson_input(geojson_text, geojson_file)
    input = read_geojson_input(geojson_text, geojson_file)
    return false if input == false
    return true if input.blank?

    result = WalkingPathGeojsonParser.parse(input)
    return @walking_path.geometry = result.geometry if result.success?

    @walking_path.errors.add(:geometry, result.error)
    false
  end

  def read_geojson_input(geojson_text, geojson_file)
    pasted = geojson_text.to_s
    uploaded = geojson_file if geojson_file.respond_to?(:read) && geojson_file.size.positive?

    if pasted.present? && uploaded.present?
      @walking_path.errors.add(:geometry, "provide either pasted GeoJSON or an uploaded .geojson file, not both")
      return false
    end

    return validate_geojson_size(pasted) if pasted.present?
    return if uploaded.blank?

    unless uploaded.original_filename.to_s.downcase.end_with?(".geojson")
      @walking_path.errors.add(:geometry, "upload must be a .geojson file")
      return false
    end

    return false if geojson_too_large?(uploaded.size)

    uploaded.read
  end

  def validate_geojson_size(input)
    return input unless geojson_too_large?(input.bytesize)

    false
  end

  def geojson_too_large?(bytesize)
    return false if bytesize <= MAX_GEOJSON_BYTES

    @walking_path.errors.add(:geometry, "GeoJSON must be smaller than #{MAX_GEOJSON_BYTES / 1.megabyte} MB")
    true
  end

  def render_form_error(template)
    flash.now[:error] = @walking_path.errors.full_messages.join("; ")
    render template, status: :unprocessable_entity
  end

  def walking_path_params
    params.require(:walking_path).permit(
      :label,
      :slug,
      :description,
      :published,
      :geojson_text,
      :geojson_file,
      area_ids: [],
      cluster_ids: []
    )
  end

  def set_walking_path
    @walking_path = WalkingPath.find(params[:id])
  end

  def set_grouping_options
    @areas = Area.order(:name, :id)
    @clusters = Cluster.order(:name, :id)
  end
end
