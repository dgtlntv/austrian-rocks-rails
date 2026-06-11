# A recommended guidebook that can be attached to regions, clusters, and areas.
# At tile export an entity without its own guidebook inherits the closest
# ancestor's (area -> cluster -> region), so a guidebook set on a region
# applies to all its descendants unless overridden.
class Guidebook < ApplicationRecord
  include MapTiles::PublishStaleMarker

  audited

  has_many :regions
  has_many :clusters
  has_many :areas

  normalizes :title, :author, :url, with: ->(s) { s.strip.presence }

  validates :title, presence: true
  validates :url, presence: true, format: { with: %r{\Ahttps?://\S+\z}i, message: "must be an http(s) URL" }
end
