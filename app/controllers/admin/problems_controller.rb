class Admin::ProblemsController < Admin::BaseController
  def index
    @area = Area.find_by(slug: params[:area_slug])

    arel = Problem.where(area_id: @area.id).order("ascents DESC NULLS LAST")

    arel = if params[:missing] == "line"
      arel.without_line_only
    elsif params[:missing] == "location"
      arel.without_location
    else
      arel
    end

    @problems = arel

    @missing_grade = @area.problems.where("grade IS NULL OR grade = ''")
  end

  def new
    area = Area.find(params[:area_id])

    @problem = Problem.new(steepness: :other)

    @problem.area = area
  end

  def create
    problem = Problem.new

    attrs = problem_params
    attrs[:video_links] = parse_video_links(attrs[:video_links]) if attrs[:video_links]

    problem.assign_attributes(attrs)

    problem.save!

    flash[:notice] = "Problem created"
    redirect_to [ :admin, problem ]
  end

  def show
    set_problem
  end

  def edit
    set_problem
  end

  def update
    set_problem

    attrs = problem_params
    attrs[:video_links] = parse_video_links(attrs[:video_links]) if attrs[:video_links]

    @problem.assign_attributes(attrs)

    if @problem.save
      flash[:notice] = "Problem updated"
      redirect_to admin_problem_path(@problem)
    else
      flash[:error] = @problem.errors.full_messages.join("; ")
      render "edit", status: :unprocessable_entity
    end
  end

  def destroy
    set_problem
    area = @problem.area

    if @problem.destroy
      flash[:notice] = "Problem destroyed"
      redirect_to admin_area_problems_path(area_slug: area.slug)
    else
      flash[:error] = @problem.errors.full_messages.join("; ")
      redirect_to admin_problem_path(@problem)
    end
  end

  def export
    include_boulders = params[:include_boulders] == "true"

    factory = RGeo::GeoJSON::EntityFactory.instance

    problem_features = Problem.with_location.joins(:area).where(area: { published: true }).map do |problem|
      hash = {}.with_indifferent_access
      hash.merge!(problem.slice(:grade, :steepness, :featured, :popularity))
      hash[:id] = problem.id

      name_de = I18n.with_locale(:de) { problem.name_with_fallback }
      name_en = I18n.with_locale(:en) { problem.name_with_fallback }
      hash[:name] = name_de
      hash[:name_en] = (name_en != name_de) ? name_en : ""

      hash.deep_transform_keys! { |key| key.camelize(:lower) }

      factory.feature(problem.location, nil, hash)
    end

    # Extract boulders alongside problems to ensure we always upload both at the same time to mapbox
    boulder_features = Boulder.where.not(area_id: [ 45, 75, 79, 104, 113 ]).joins(:area).where(area: { published: true }).map do |boulder|
      hash = {}.with_indifferent_access
      hash[:name] = boulder.name if boulder.name.present?
      hash.deep_transform_keys! { |key| key.camelize(:lower) }

      factory.feature(boulder.polygon, nil, hash)
    end

    if include_boulders
      features = problem_features + boulder_features
    else
      features = problem_features
    end

    feature_collection = factory.feature_collection(
      features
    )

    geo_json = JSON.pretty_generate(RGeo::GeoJSON.encode(feature_collection))

    filename = include_boulders ? "problems.geojson" : "problems-without-boulders.geojson"

    respond_to do |format|
      format.geojson do
        send_data geo_json, filename: filename, type: "application/geo+json"
      end
    end
  end

  private
  def problem_params
    params.require(:problem).
      permit(:area_id, :name, :grade, :steepness, :sit_start,
        :parent_id, :description, :video_links,
      )
  end

  def parse_video_links(video_links_str)
    return [] if video_links_str.blank?
    video_links_str.split("\n").map(&:strip).reject(&:blank?)
  end

  def set_problem
    @problem = Problem.find(params[:id])
  end
end
