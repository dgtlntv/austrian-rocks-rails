module ProblemsHelper
  def bleau_info_url(problem)
    "https://bleau.info/c/#{problem.bleau_info_id}.html" if problem.bleau_info_id.present?
  end

  def problem_friendly_path(problem)
    area_problem_path(problem.area, problem)
  end
end
