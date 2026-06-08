class Boulder < ApplicationRecord
  belongs_to :area
  has_many :problems
  has_many :topos

  validates :name, length: { maximum: 255 }, allow_blank: true

  audited associated_with: :import
  attr_accessor :import # used by audited associated_with: :import
  include CheckConflicts
  include MapTiles::PublishStaleMarker
end
