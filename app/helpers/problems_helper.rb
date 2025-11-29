module ProblemsHelper
  def problem_friendly_path(problem)
    area_problem_path(problem.area, problem)
  end
end
