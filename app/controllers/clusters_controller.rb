class ClustersController < ApplicationController
  def show
    @region = Region.published.find_by!(slug: params[:region_slug])
    @cluster = @region.clusters.published.find_by!(slug: params[:cluster_slug])
    @areas_with_count = @cluster.areas.published.map { |area| [area, area.problems.with_location.count] }.sort_by { |a, _| I18n.transliterate(a.name) }

    # Check if there are areas with specific tags for conditional filter display
    @has_beginner_areas = @cluster.areas.published.any_tags(:beginner_friendly).exists?
    @has_dry_fast_areas = @cluster.areas.published.any_tags(:dry_fast).exists?
  end
end
