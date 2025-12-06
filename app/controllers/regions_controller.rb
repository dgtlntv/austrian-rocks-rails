class RegionsController < ApplicationController
  def index
    @regions = Region.published.sort_by { |r| I18n.transliterate(r.name) }
  end

  def show
    @region = Region.published.find_by!(slug: params[:region_slug])
    @clusters = @region.clusters.published.sort_by { |c| I18n.transliterate(c.name) }
  end
end
