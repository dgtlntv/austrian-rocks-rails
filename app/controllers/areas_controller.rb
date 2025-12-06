class AreasController < ApplicationController
  def index
    # see https://guides.rubyonrails.org/caching_with_rails.html#avoid-caching-instances-of-active-record-objects
    @popular_areas_ids = Rails.cache.fetch("areas/index/popular_areas_ids", expires_in: 12.hours) do
      Area.published.any_tags(:popular).pluck(:id).shuffle
    end

    @areas_with_count = Area.published.sort_by { |a| I18n.transliterate(a.name) }
  end

  def levels
    # see https://guides.rubyonrails.org/caching_with_rails.html#avoid-caching-instances-of-active-record-objects
    @beginner_areas_ids = Rails.cache.fetch("areas/levels/beginner_areas_ids", expires_in: 12.hours) do
      Area.beginner_friendly.pluck(:id)
    end

    @areas_with_count = Area.published.map { |area| [ area, area.problems.with_location.count ] }.sort { |a, b| b.second <=> a.second }
  end

  def show
    @region = Region.find_by!(slug: params[:region_slug])
    @cluster = @region.clusters.find_by!(slug: params[:cluster_slug])
    @area = @cluster.areas.find_by!(slug: params[:area_slug])

    @popular_problems = @area.problems.with_location.where(featured: true).order(grade: :desc, popularity: :desc)
  end

  def problems
    @region = Region.find_by!(slug: params[:region_slug])
    @cluster = @region.clusters.find_by!(slug: params[:cluster_slug])
    @area = @cluster.areas.find_by!(slug: params[:area_slug])

    @problems = @area.problems.with_location.order(popularity: :desc).group_by { |p| p.grade }.sort_by { |grade, _| grade || "" }.reverse
  end
end
