module ProblemsHelper
  def problem_friendly_path(problem)
    area_problem_path(problem.area, problem)
  end

  def circle_view(content, klass: "h-6 w-6 leading-6")
    content_tag(:span, content,
      class: "rounded-full #{klass} inline-flex justify-center bg-brand-500")
  end
end
