# frozen_string_literal: true

require "map_tiles/cli"

namespace :map_tiles do
  desc "Export deterministic PMTiles source-layer GeoJSON"
  task export: :environment do
    exit MapTiles::CLI.new([ "export" ]).run
  end

  desc "Export GeoJSON and build Austrian Rocks PMTiles with Tippecanoe"
  task :build, [ :version ] => :environment do |_task, args|
    exit MapTiles::CLI.new([ "build", "--version", args[:version].to_s ]).run
  end

  desc "Run map tile smoke checks"
  task :smoke, [ :version, :mode, :allow_empty ] => :environment do |_task, args|
    argv = [ "smoke", "--version", args[:version].to_s ]
    argv.push("--mode", args[:mode].to_s) if args[:mode].present?
    argv.push("--allow-empty", args[:allow_empty].to_s) if args[:allow_empty].present?

    exit MapTiles::CLI.new(argv).run
  end

  desc "Publish Austrian Rocks PMTiles and latest manifest to Bunny/CDN"
  task :publish, [ :version, :skip_smoke ] => :environment do |_task, args|
    argv = [ "publish", "--version", args[:version].to_s ]
    argv << "--skip-smoke" if %w[1 true yes on].include?(args[:skip_smoke].to_s.strip.downcase)

    exit MapTiles::CLI.new(argv).run
  end

  desc "Publish committed MapLibre font glyph PBFs to Bunny/CDN"
  task publish_fonts: :environment do
    exit MapTiles::CLI.new([ "publish-fonts" ]).run
  end
end
