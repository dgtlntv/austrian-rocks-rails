class WalkingPath < ApplicationRecord
  has_many :walking_path_areas, dependent: :destroy
  has_many :areas, through: :walking_path_areas
  has_many :walking_path_clusters, dependent: :destroy
  has_many :clusters, through: :walking_path_clusters

  normalizes :label, :slug, :description, with: ->(value) { value.strip.presence }

  validates :slug, presence: true, uniqueness: true, if: :published?
  validate :geometry_is_line
  validate :geometry_has_expected_srid
  validate :published_geometry_present

  def geometry_geojson
    return if geometry.blank?

    JSON.pretty_generate(RGeo::GeoJSON.encode(geometry))
  end

  private

  def published_geometry_present
    errors.add(:geometry, "must be present when published") if published? && geometry.blank?
  end

  def geometry_is_line
    return if geometry.blank?
    return if geometry.is_a?(RGeo::Feature::LineString) || geometry.is_a?(RGeo::Feature::MultiLineString)

    errors.add(:geometry, "must be a LineString or MultiLineString")
  end

  def geometry_has_expected_srid
    return if geometry.blank? || geometry.srid == 4326

    errors.add(:geometry, "must use SRID 4326")
  end
end
