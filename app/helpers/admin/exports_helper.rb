module Admin::ExportsHelper
  MAP_TILE_STATUS_LABELS = {
    "up_to_date" => "up to date",
    "stale" => "stale",
    "pending" => "pending",
    "running" => "running",
    "failed" => "failed"
  }.freeze

  MAP_TILE_STATUS_CLASSES = {
    "up_to_date" => "bg-green-100 text-green-800",
    "stale" => "bg-yellow-100 text-yellow-800",
    "pending" => "bg-blue-100 text-blue-800",
    "running" => "bg-purple-100 text-purple-800",
    "failed" => "bg-red-100 text-red-800"
  }.freeze

  BUNNY_SECRET_KEYS = %w[
    BUNNY_STORAGE_ACCESS_KEY_ID
    BUNNY_STORAGE_SECRET_ACCESS_KEY
    BUNNY_CDN_API_KEY
    BUNNY_API_KEY
  ].freeze

  def map_tile_status_label(status)
    MAP_TILE_STATUS_LABELS.fetch(status.to_s, status.to_s.humanize.downcase)
  end

  def map_tile_status_badge_class(status)
    [ "inline-flex rounded-full px-2 py-1 text-xs font-semibold", MAP_TILE_STATUS_CLASSES.fetch(status.to_s, "bg-gray-100 text-gray-800") ].join(" ")
  end

  def map_tile_timestamp(time)
    return "—" if time.blank?

    time.in_time_zone.strftime("%Y-%m-%d %H:%M:%S %Z")
  end

  def map_tile_duration(duration)
    return "—" if duration.blank?

    seconds = duration.round
    minutes, remaining_seconds = seconds.divmod(60)
    hours, remaining_minutes = minutes.divmod(60)

    if hours.positive?
      "#{hours}h #{remaining_minutes}m #{remaining_seconds}s"
    elsif minutes.positive?
      "#{minutes}m #{remaining_seconds}s"
    else
      "#{remaining_seconds}s"
    end
  end

  def map_tile_external_link(url, label: "Open")
    return "—" if url.blank?

    link_to label, url, target: "_blank", rel: "noopener noreferrer", class: "text-brand-600 hover:text-brand-800 underline"
  end

  def map_tile_safe_error_text(attempt)
    text = attempt.error_text.to_s
    return "—" if text.blank?

    BUNNY_SECRET_KEYS.each do |key|
      text = text.gsub(/#{Regexp.escape(key)}=[^\s]*/i, "[REDACTED #{key}]")
    end

    BUNNY_SECRET_KEYS.filter_map { |key| ENV[key].to_s.presence }.each do |value|
      text = text.gsub(Regexp.new(Regexp.escape(value)), "[REDACTED VALUE]")
    end

    truncate(text, length: 500)
  end
end
