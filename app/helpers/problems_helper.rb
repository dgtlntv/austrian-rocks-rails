module ProblemsHelper
  def problem_friendly_path(problem)
    area_problem_path(problem.area, problem)
  end

  def circle_view(content, klass: "h-6 w-6 leading-6")
    content_tag(:span, content,
      class: "rounded-full #{klass} inline-flex justify-center bg-brand-500")
  end

  def video_platform_info(url)
    uri = URI.parse(url)
    host = uri.host.to_s.downcase

    case host
    when /youtube\.com/, /youtu\.be/
      { name: "YouTube", icon: "youtube", color: "red" }
    when /vimeo\.com/
      { name: "Vimeo", icon: "vimeo", color: "blue" }
    when /instagram\.com/
      { name: "Instagram", icon: "instagram", color: "pink" }
    when /tiktok\.com/
      { name: "TikTok", icon: "tiktok", color: "black" }
    else
      { name: "Video", icon: "play", color: "gray" }
    end
  rescue URI::InvalidURIError
    { name: "Video", icon: "play", color: "gray" }
  end
end
