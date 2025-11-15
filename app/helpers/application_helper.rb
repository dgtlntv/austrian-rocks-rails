module ApplicationHelper
  # Override the translate method to automatically inject brand_name
  def t(key, **options)
    super(key, **options.reverse_merge(brand_name: BRAND_CONFIG[:name]))
  end
  alias_method :translate, :t
end
