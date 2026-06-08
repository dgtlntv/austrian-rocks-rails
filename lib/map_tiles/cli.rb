# frozen_string_literal: true

require "map_tiles/layer_contract"
require "map_tiles/configuration"
require "map_tiles/geojson_exporter"
require "map_tiles/tippecanoe_builder"
require "map_tiles/smoke_check"
require "map_tiles/bunny_publisher"

module MapTiles
  class CLI
    attr_reader :argv, :configuration, :out, :err

    def initialize(argv = ARGV, configuration: Configuration.new, out: $stdout, err: $stderr)
      @argv = argv.dup
      @configuration = configuration
      @out = out
      @err = err
    end

    def self.start(argv = ARGV)
      new(argv).run
    end

    def run
      command = argv.shift || "build"

      case command
      when "export"
        export
      when "build"
        build
      when "smoke"
        smoke
      when "publish"
        publish
      else
        err.puts "Unknown map tiles command: #{command}"
        err.puts "Usage: bin/build_pmtiles [export|build|smoke|publish]"
        1
      end
    rescue TippecanoeBuilder::Error, SmokeCheck::Error, BunnyPublisher::Error, KeyError, ArgumentError => e
      err.puts e.message
      1
    end

    private

    def export
      paths = GeojsonExporter.new(configuration: configuration).export
      paths.each { |layer_name, path| out.puts "exported #{layer_name} -> #{path}" }
      0
    end

    def build
      paths = GeojsonExporter.new(configuration: configuration).export
      artifact_path = TippecanoeBuilder.new(configuration: configuration).build(layer_paths: paths)
      out.puts "built #{artifact_path}"
      0
    end

    def smoke
      MapTiles::SmokeCheck.new(configuration: configuration, argv: argv, out: out).run
      0
    end

    def publish
      unless skip_smoke?
        out.puts "running production PMTiles smoke check before publish"
        MapTiles::SmokeCheck.new(configuration: configuration, argv: [ "--mode=production" ], out: out).run
      end

      MapTiles::BunnyPublisher.new(configuration: configuration, out: out).publish
      0
    end

    def skip_smoke?
      %w[1 true yes on].include?(configuration.env["MAP_TILES_SKIP_SMOKE"].to_s.strip.downcase)
    end
  end
end
