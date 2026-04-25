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
