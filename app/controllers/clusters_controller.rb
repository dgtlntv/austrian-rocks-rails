class ClustersController < ApplicationController
  def show
    @region = Region.published.find_by!(slug: params[:region_slug])
    @cluster = @region.clusters.published.find_by!(slug: params[:cluster_slug])
    @areas_with_count = @cluster.areas.published.map { |area| [area, area.problems.with_location.count] }.sort_by { |a, _| I18n.transliterate(a.name) }
  end
end
