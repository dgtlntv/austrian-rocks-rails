class Region < ApplicationRecord
  include CheckConflicts
  include HasTagsConcern
  include MapTiles::PublishStaleMarker

  audited associated_with: :import
  attr_accessor :import # used by audited associated_with: :import

  has_many :clusters
  belongs_to :guidebook, optional: true
  belongs_to :parking_poi, class_name: "Poi", optional: true

  has_one_attached :cover do |attachable|
    attachable.variant :thumb, resize_to_limit: [ 400, 400 ], saver: { quality: 80, strip: true, interlace: true }, preprocessed: true
    attachable.variant :medium, resize_to_limit: [ 800, 800 ], saver: { quality: 80, strip: true, interlace: true }, preprocessed: true
  end

  scope :published, -> { where(published: true) }

  normalizes :warning_de, :warning_en, with: ->(s) { s.strip.presence }

  validates :slug, presence: true, if: :published?
  validates :tags, array: { inclusion: { in: %w[popular] } }
  validate :parking_poi_must_be_parking

  def to_param
    slug || id.to_s
  end

  private

  def parking_poi_must_be_parking
    return if parking_poi.nil? || parking_poi.parking?

    errors.add(:parking_poi, "must be a parking POI")
  end
end
