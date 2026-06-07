# frozen_string_literal: true

require "fileutils"
require "map_tiles/configuration"

module MapTiles
  class TippecanoeBuilder
    class Error < StandardError; end
    class MissingExecutableError < Error; end
    class BuildError < Error; end

    INSTALL_GUIDANCE = <<~TEXT.squish
      Tippecanoe is required to build Austrian Rocks PMTiles. Install it with `brew install tippecanoe` on macOS, or follow https://github.com/mapbox/tippecanoe for your platform, then rerun the build.
    TEXT

    attr_reader :configuration, :executable, :executable_checker, :command_runner

    def initialize(configuration: Configuration.new, executable: "tippecanoe", executable_checker: nil, command_runner: nil)
      @configuration = configuration
      @executable = executable
      @executable_checker = executable_checker || ->(binary) { executable_on_path?(binary) }
      @command_runner = command_runner || ->(command) { system(*command) }
    end

    def build(layer_paths:)
      ensure_tippecanoe_available!
      FileUtils.mkdir_p(configuration.output_dir)

      command = build_command(layer_paths: layer_paths)
      success = command_runner.call(command)
      raise BuildError, "Tippecanoe failed while building #{configuration.artifact_path}" unless success

      configuration.artifact_path
    end

    def build_command(layer_paths:)
      ordered_layer_paths = LayerContract.layer_names.to_h do |layer_name|
        path = layer_paths.fetch(layer_name) { raise KeyError, "missing GeoJSON path for layer #{layer_name}" }
        [ layer_name, path ]
      end

      [
        executable,
        "--force",
        "--minimum-zoom=0",
        "--maximum-zoom=#{LayerContract.native_max_zoom}",
        "--output=#{configuration.artifact_path}",
        *ordered_layer_paths.flat_map { |layer_name, path| [ "--named-layer=#{layer_name}:#{path}" ] }
      ]
    end

    private

    def ensure_tippecanoe_available!
      return if executable_checker.call(executable)

      raise MissingExecutableError, INSTALL_GUIDANCE
    end

    def executable_on_path?(binary)
      ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? do |directory|
        path = File.join(directory, binary)
        File.file?(path) && File.executable?(path)
      end
    end
  end
end
