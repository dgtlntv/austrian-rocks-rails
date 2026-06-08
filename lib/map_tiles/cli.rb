# frozen_string_literal: true

require "map_tiles/layer_contract"
require "map_tiles/configuration"
require "map_tiles/geojson_exporter"
require "map_tiles/tippecanoe_builder"
require "map_tiles/smoke_check"
require "map_tiles/bunny_publisher"

module MapTiles
  class CLI
    USAGE = "Usage: bin/build_pmtiles [export|build|smoke|publish] [--version=<value>] [--skip-smoke]"

    attr_reader :argv, :configuration, :out, :err, :exporter_class, :builder_class, :smoke_check_class, :publisher_class

    def initialize(
      argv = ARGV,
      configuration: Configuration.new,
      out: $stdout,
      err: $stderr,
      exporter_class: GeojsonExporter,
      builder_class: TippecanoeBuilder,
      smoke_check_class: SmokeCheck,
      publisher_class: BunnyPublisher
    )
      @argv = argv.dup
      @configuration = configuration
      @out = out
      @err = err
      @exporter_class = exporter_class
      @builder_class = builder_class
      @smoke_check_class = smoke_check_class
      @publisher_class = publisher_class
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
        err.puts USAGE
        1
      end
    rescue TippecanoeBuilder::Error, SmokeCheck::Error, BunnyPublisher::Error, KeyError, ArgumentError => e
      err.puts e.message
      err.puts USAGE
      1
    end

    private

    def export
      reject_unknown_options!(argv)

      paths = exporter_class.new(configuration: configuration).export
      paths.each { |layer_name, path| out.puts "exported #{layer_name} -> #{path}" }
      0
    end

    def build
      versioned_configuration, remaining_argv = configuration_with_required_version!
      reject_unknown_options!(remaining_argv)

      paths = exporter_class.new(configuration: versioned_configuration).export
      artifact_path = builder_class.new(configuration: versioned_configuration).build(layer_paths: paths)
      out.puts "built #{artifact_path}"
      0
    end

    def smoke
      versioned_configuration, smoke_argv = configuration_with_required_version!

      smoke_check_class.new(configuration: versioned_configuration, argv: smoke_argv, out: out).run
      0
    end

    def publish
      versioned_configuration, remaining_argv = configuration_with_required_version!
      skip_smoke = extract_skip_smoke!(remaining_argv)
      reject_unknown_options!(remaining_argv)

      unless skip_smoke
        out.puts "running production PMTiles smoke check before publish"
        smoke_check_class.new(configuration: versioned_configuration, argv: [ "--mode=production" ], out: out).run
      end

      publisher_class.new(configuration: versioned_configuration, out: out).publish
      0
    end

    def configuration_with_required_version!
      parsed_argv = argv.dup
      version = nil
      remaining_argv = []

      until parsed_argv.empty?
        option = parsed_argv.shift

        case option
        when /\A--version=(.*)\z/
          raise ArgumentError, "--version may only be provided once" if version

          version = Regexp.last_match(1)
        when "--version"
          raise ArgumentError, "--version requires a value" if parsed_argv.empty?
          raise ArgumentError, "--version may only be provided once" if version

          version = parsed_argv.shift
        else
          remaining_argv << option
        end
      end

      raise ArgumentError, Configuration::VERSION_REQUIRED_MESSAGE if version.to_s.strip.blank?

      [ configuration.with_version(version), remaining_argv ]
    end

    def extract_skip_smoke!(remaining_argv)
      skip_smoke = false
      remaining_argv.delete_if do |option|
        if option == "--skip-smoke"
          skip_smoke = true
        else
          false
        end
      end
      skip_smoke
    end

    def reject_unknown_options!(remaining_argv)
      return if remaining_argv.empty?

      raise ArgumentError, "Unknown map tiles option(s): #{remaining_argv.join(', ')}"
    end
  end

  Cli = CLI unless const_defined?(:Cli, false)
end
