# frozen_string_literal: true

require "map_tiles/cli"

namespace :map_tiles do
  desc "Export deterministic PMTiles source-layer GeoJSON"
  task export: :environment do
    exit MapTiles::CLI.new([ "export" ]).run
  end

  desc "Export GeoJSON and build Austrian Rocks PMTiles with Tippecanoe"
  task build: :environment do
    exit MapTiles::CLI.new([ "build" ]).run
  end

  desc "Run map tile smoke checks"
  task smoke: :environment do
    exit MapTiles::CLI.new([ "smoke" ]).run
  end

  desc "Publish Austrian Rocks PMTiles to Bunny/CDN"
  task publish: :environment do
    exit MapTiles::CLI.new([ "publish" ]).run
  end
end
