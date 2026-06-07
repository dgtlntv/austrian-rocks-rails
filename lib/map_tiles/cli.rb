# frozen_string_literal: true

require "map_tiles/layer_contract"
require "map_tiles/configuration"
require "map_tiles/geojson_exporter"
require "map_tiles/tippecanoe_builder"

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
    rescue TippecanoeBuilder::Error, KeyError, ArgumentError => e
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
      require "map_tiles/smoke_check"
      MapTiles::SmokeCheck.new(configuration: configuration, argv: argv).run
      0
    rescue LoadError
      err.puts "map_tiles smoke is implemented in phase 0004-P3"
      1
    end

    def publish
      require "map_tiles/bunny_publisher"
      MapTiles::BunnyPublisher.new(configuration: configuration).publish
      0
    rescue LoadError
      err.puts "map_tiles publish is implemented in phase 0004-P4"
      1
    end
  end
end
