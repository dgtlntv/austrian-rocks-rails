# frozen_string_literal: true

require "test_helper"
require "securerandom"
require "stringio"
require "map_tiles/cli"

class MapTiles::CLITest < ActiveSupport::TestCase
  setup do
    @calls = { exports: [], builds: [], smokes: [], publishes: [], font_publishes: [], cleans: [] }
    @settings = {
      "artifact_basename" => "austrian-rocks",
      "output_dir" => "tmp/cli_test/#{SecureRandom.hex(8)}",
      "public_cdn_host" => "https://cdn.example.test",
      "bunny_prefix" => "maps",
      "style_prefix" => "map_styles",
      "manifest_prefix" => "map_tiles",
      "manifest_object_name" => "current.json",
      "default_style" => "light",
      "basemap_at_style_url" => "https://basemap.bergwerk-gis.at/api/styles/basemap-at-farbe",
      "basemap_at_attribution" => "Grundkarte: <a href=\"https://basemap.at/\" target=\"_blank\" rel=\"noopener noreferrer\">basemap.at</a>",
      "terrain_opacity" => 0.35,
      "optional_production_layers" => [],
      "automatic_publish_debounce_minutes" => "30",
      "manifest_cache_ttl_seconds" => "60",
      "pmtiles_cache_control" => "public, max-age=31536000, immutable",
      "manifest_content_type" => "application/json"
    }
    @configuration = MapTiles::Configuration.new(settings: @settings)
    @exporter_class = exporter_class(@calls)
    @builder_class = builder_class(@calls)
    @smoke_check_class = smoke_check_class(@calls)
    @publisher_class = publisher_class(@calls)
    @font_publisher_class = font_publisher_class(@calls)
    @cleaner_class = cleaner_class(@calls)
  end

  test "export does not require a version" do
    out = StringIO.new

    status = run_cli([ "export" ], out: out)

    assert_equal 0, status
    assert_equal 1, @calls.fetch(:exports).length
    assert_nil @calls.fetch(:exports).first.fetch(:version)
    assert_includes out.string, "exported problems"
  end

  test "build requires explicit version" do
    err = StringIO.new

    status = run_cli([ "build" ], err: err)

    assert_equal 1, status
    assert_includes err.string, "--version is required for build, smoke, and publish"
    assert_empty @calls.fetch(:builds)
  end

  test "build accepts equals and space version forms" do
    assert_equal 0, run_cli([ "build", "--version=2026-06-07" ])
    assert_equal "2026-06-07", @calls.fetch(:builds).last.fetch(:version)

    assert_equal 0, run_cli([ "build", "--version", "2026-06-08" ])
    assert_equal "2026-06-08", @calls.fetch(:builds).last.fetch(:version)
  end

  test "smoke requires explicit safe version and passes smoke options through" do
    unsafe_err = StringIO.new
    unsafe_status = run_cli([ "smoke", "--version", "2026/06/07" ], err: unsafe_err)

    assert_equal 1, unsafe_status
    assert_includes unsafe_err.string, "--version must contain only letters"

    status = run_cli([ "smoke", "--version", "2026-06-07", "--mode", "production", "--allow-empty=pois" ])

    assert_equal 0, status
    assert_equal "2026-06-07", @calls.fetch(:smokes).last.fetch(:version)
    assert_equal [ "--mode", "production", "--allow-empty=pois" ], @calls.fetch(:smokes).last.fetch(:argv)
  end

  test "publish runs production smoke by default" do
    out = StringIO.new

    status = run_cli([ "publish", "--version=2026-06-07" ], out: out)

    assert_equal 0, status
    assert_includes out.string, "running production PMTiles smoke check before publish"
    assert_equal [ "--mode=production" ], @calls.fetch(:smokes).last.fetch(:argv)
    assert_equal "2026-06-07", @calls.fetch(:publishes).last.fetch(:version)
    assert_equal "2026-06-07", @calls.fetch(:cleans).last.fetch(:version)
    assert_includes out.string, "current manifest -> https://cdn.example.test/map_tiles/current.json"
  end

  test "publish-fonts publishes static fonts without version, smoke, release publish, or clean" do
    out = StringIO.new

    status = run_cli([ "publish-fonts" ], out: out)

    assert_equal 0, status
    assert_equal 1, @calls.fetch(:font_publishes).length
    assert_nil @calls.fetch(:font_publishes).last.fetch(:version)
    assert_empty @calls.fetch(:smokes)
    assert_empty @calls.fetch(:publishes)
    assert_empty @calls.fetch(:cleans)
    assert_includes out.string, "published fonts"
  end

  test "publish-fonts rejects unknown options" do
    err = StringIO.new

    status = run_cli([ "publish-fonts", "--version=2026-06-07" ], err: err)

    assert_equal 1, status
    assert_includes err.string, "Unknown map tiles option(s): --version=2026-06-07"
    assert_includes err.string, "publish-fonts"
    assert_empty @calls.fetch(:font_publishes)
  end

  test "publish-fonts reports font publisher errors with usage" do
    err = StringIO.new
    failing_font_publisher_class = Class.new do
      define_method(:initialize) do |configuration:, out:|
      end

      define_method(:publish) do
        raise MapTiles::FontPublisher::Error, "font publish failed"
      end
    end

    status = run_cli([ "publish-fonts" ], err: err, font_publisher_class: failing_font_publisher_class)

    assert_equal 1, status
    assert_includes err.string, "font publish failed"
    assert_includes err.string, "Usage: bin/build_pmtiles"
  end

  test "publish skip smoke is the only smoke bypass" do
    env = { "MAP_TILES_SKIP_SMOKE" => "true" }
    env_configuration = MapTiles::Configuration.new(env: env, settings: @settings)

    status = run_cli([ "publish", "--version=2026-06-07" ], configuration: env_configuration)
    assert_equal 0, status
    assert_equal 1, @calls.fetch(:smokes).length, "legacy MAP_TILES_SKIP_SMOKE must be ignored"

    status = run_cli([ "publish", "--version=2026-06-08", "--skip-smoke" ], configuration: env_configuration)
    assert_equal 0, status
    assert_equal 1, @calls.fetch(:smokes).length, "explicit --skip-smoke suppresses publish smoke"
    assert_equal "2026-06-08", @calls.fetch(:publishes).last.fetch(:version)
  end

  test "space-form version rejects a following option token" do
    err = StringIO.new

    status = run_cli([ "build", "--version", "--bogus" ], err: err)

    assert_equal 1, status
    assert_includes err.string, "--version requires a value"
    assert_empty @calls.fetch(:builds)
  end

  test "unknown command options fail with usage" do
    err = StringIO.new

    status = run_cli([ "build", "--version=2026-06-07", "--bogus" ], err: err)

    assert_equal 1, status
    assert_includes err.string, "Unknown map tiles option"
    assert_includes err.string, "Usage: bin/build_pmtiles"
  end

  private

  def run_cli(argv, configuration: @configuration, out: StringIO.new, err: StringIO.new, font_publisher_class: @font_publisher_class)
    MapTiles::CLI.new(
      argv,
      configuration: configuration,
      out: out,
      err: err,
      exporter_class: @exporter_class,
      builder_class: @builder_class,
      smoke_check_class: @smoke_check_class,
      publisher_class: @publisher_class,
      font_publisher_class: font_publisher_class,
      cleaner_class: @cleaner_class
    ).run
  end

  def exporter_class(calls)
    Class.new do
      define_method(:initialize) do |configuration:|
        @configuration = configuration
      end

      define_method(:export) do
        version = @configuration.version if @configuration.instance_variable_get(:@version).present?
        calls.fetch(:exports) << { version: version }
        { "problems" => Rails.root.join("tmp/problems.geojson") }
      end
    end
  end

  def builder_class(calls)
    Class.new do
      define_method(:initialize) do |configuration:|
        @configuration = configuration
      end

      define_method(:build) do |layer_paths:|
        calls.fetch(:builds) << { version: @configuration.version, layer_paths: layer_paths }
        @configuration.artifact_path
      end
    end
  end

  def smoke_check_class(calls)
    Class.new do
      define_method(:initialize) do |configuration:, argv:, out:|
        @configuration = configuration
        @argv = argv
        @out = out
      end

      define_method(:run) do
        calls.fetch(:smokes) << { version: @configuration.version, argv: @argv }
      end
    end
  end

  def publisher_class(calls)
    Class.new do
      define_method(:initialize) do |configuration:, out:|
        @configuration = configuration
        @out = out
      end

      define_method(:publish) do
        calls.fetch(:publishes) << { version: @configuration.version }
        [
          {
            key: @configuration.versioned_object_key,
            url: "https://cdn.example.test/#{@configuration.versioned_object_key}"
          },
          {
            key: @configuration.style_object_key("light"),
            url: "https://cdn.example.test/#{@configuration.style_object_key("light")}"
          },
          {
            key: @configuration.style_object_key("dark"),
            url: "https://cdn.example.test/#{@configuration.style_object_key("dark")}"
          },
          {
            key: @configuration.manifest_object_key,
            url: "https://cdn.example.test/#{@configuration.manifest_object_key}"
          }
        ]
      end
    end
  end

  def font_publisher_class(calls)
    Class.new do
      define_method(:initialize) do |configuration:, out:|
        @configuration = configuration
        @out = out
      end

      define_method(:publish) do
        version = @configuration.instance_variable_get(:@version) if @configuration.instance_variable_get(:@version).present?
        calls.fetch(:font_publishes) << { version: version }
        @out.puts "published fonts"
        [
          {
            key: "map_styles/fonts/inter-v1/Inter Regular/0-255.pbf",
            url: "https://cdn.example.test/map_styles/fonts/inter-v1/Inter%20Regular/0-255.pbf"
          }
        ]
      end
    end
  end

  def cleaner_class(calls)
    Class.new do
      define_method(:initialize) do |configuration:, out:|
        @configuration = configuration
        @out = out
      end

      define_method(:clean) do
        calls.fetch(:cleans) << { version: @configuration.version }
      end
    end
  end
end
