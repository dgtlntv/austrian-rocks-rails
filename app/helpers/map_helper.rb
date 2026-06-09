# frozen_string_literal: true

module MapHelper
  def map_release_manifest_url
    MapTiles::Configuration.new.manifest_public_url
  end

  def map_default_style
    MapTiles::Configuration.new.default_style
  end
end
