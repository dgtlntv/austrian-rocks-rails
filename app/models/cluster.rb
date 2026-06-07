class Cluster < ApplicationRecord
  include CheckConflicts
  include HasTagsConcern

  audited associated_with: :import
  attr_accessor :import # used by audited associated_with: :import

  belongs_to :region, optional: true
  has_many :areas
  has_many :walking_path_clusters, dependent: :destroy
  has_many :walking_paths, through: :walking_path_clusters

  has_one_attached :cover do |attachable|
    attachable.variant :thumb, resize_to_limit: [ 400, 400 ], saver: { quality: 80, strip: true, interlace: true }, preprocessed: true
    attachable.variant :medium, resize_to_limit: [ 800, 800 ], saver: { quality: 80, strip: true, interlace: true }, preprocessed: true
  end

  scope :published, -> { where(published: true) }

  validates :slug, presence: true, if: :published?
  validates :tags, array: { inclusion: { in: %w[popular] } }

  def to_param
    slug || id.to_s
  end
end
