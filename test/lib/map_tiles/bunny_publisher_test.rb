# frozen_string_literal: true

require "test_helper"
require "securerandom"
require "stringio"
require "map_tiles/bunny_publisher"

class MapTiles::BunnyPublisherTest < ActiveSupport::TestCase
  setup do
    @output_dir = Rails.root.join("tmp/bunny_publisher_test/#{SecureRandom.hex(8)}")
    @env = publication_env
    @configuration = MapTiles::Configuration.new(version: "2026-06-07", env: @env, settings: map_tile_settings)
    FileUtils.mkdir_p(@configuration.output_dir)
    @configuration.artifact_path.binwrite("pmtiles")
    @s3_client = FakeS3Client.new
    @head_urls = []
    @http_head = ->(uri) { @head_urls << uri.to_s; FakeHeadResponse.new(200) }
    @style_materializer = FakeStyleMaterializer.new(@configuration)
    @release_manifest = FakeReleaseManifest.new(@configuration)
  end

  teardown do
    FileUtils.rm_rf(@output_dir)
  end

  test "requires Bunny secret environment configuration" do
    configuration = MapTiles::Configuration.new(
      version: "2026-06-07",
      env: @env.except("BUNNY_STORAGE_SECRET_ACCESS_KEY"),
      settings: map_tile_settings
    )
    publisher = build_publisher(configuration: configuration)

    error = assert_raises(MapTiles::BunnyPublisher::ConfigurationError) { publisher.publish }

    assert_includes error.message, "BUNNY_STORAGE_SECRET_ACCESS_KEY"
    assert_not_includes error.message, "MAP_TILES_PUBLIC_CDN_HOST"
    assert_not_includes error.message, "super-secret"
  end

  test "requires config-backed publication settings" do
    configuration = MapTiles::Configuration.new(version: "2026-06-07", env: @env, settings: map_tile_settings("public_cdn_host" => ""))
    publisher = build_publisher(configuration: configuration)

    error = assert_raises(MapTiles::BunnyPublisher::ConfigurationError) { publisher.publish }

    assert_includes error.message, "Configured public CDN host is required"
    assert_not_includes error.message, "MAP_TILES_PUBLIC_CDN_HOST"
  end

  test "requires existing non-empty PMTiles artifact" do
    @configuration.artifact_path.delete

    missing = assert_raises(MapTiles::BunnyPublisher::ConfigurationError) { build_publisher.publish }
    assert_includes missing.message, "PMTiles artifact is missing"

    @configuration.artifact_path.binwrite("")
    empty = assert_raises(MapTiles::BunnyPublisher::ConfigurationError) { build_publisher.publish }
    assert_includes empty.message, "PMTiles artifact is empty"
  end

  test "constructs sanitized versioned style and manifest object keys" do
    assert_equal "maps/austrian-rocks-2026-06-07.pmtiles", @configuration.versioned_object_key
    assert_equal "styles/austrian-rocks-2026-06-07-light.json", @configuration.style_object_key("light")
    assert_equal "styles/austrian-rocks-2026-06-07-dark.json", @configuration.style_object_key("dark")
    assert_equal "maps/current.json", @configuration.manifest_object_key
    assert_not_respond_to @configuration, :"latest_#{'object'}_key"

    bad_configuration = MapTiles::Configuration.new(version: "2026/06/07", env: @env, settings: map_tile_settings)

    assert_raises(ArgumentError) { bad_configuration.versioned_object_key }

    blank_prefix_configuration = MapTiles::Configuration.new(version: "2026-06-07", env: @env, settings: map_tile_settings("bunny_prefix" => "/"))
    publisher = build_publisher(configuration: blank_prefix_configuration)

    error = assert_raises(MapTiles::BunnyPublisher::ConfigurationError) { publisher.publish }
    assert_includes error.message, "Configured Bunny prefix"
  end

  test "uploads immutable PMTiles and styles plus non-cached manifest and verifies public urls" do
    out = StringIO.new
    publisher = build_publisher(out: out)

    published = publisher.publish

    assert @style_materializer.called
    assert @release_manifest.called
    assert_equal(
      %w[
        maps/austrian-rocks-2026-06-07.pmtiles
        styles/austrian-rocks-2026-06-07-light.json
        styles/austrian-rocks-2026-06-07-dark.json
        maps/current.json
      ],
      @s3_client.puts.map { |put| put.fetch(:key) }
    )
    assert_equal(
      [
        "https://cdn.example.test/maps/austrian-rocks-2026-06-07.pmtiles",
        "https://cdn.example.test/styles/austrian-rocks-2026-06-07-light.json",
        "https://cdn.example.test/styles/austrian-rocks-2026-06-07-dark.json",
        "https://cdn.example.test/maps/current.json"
      ],
      @head_urls
    )
    assert_equal @head_urls, published.map { |object| object.fetch(:url) }
    assert_equal [
      "application/octet-stream",
      "application/json; charset=utf-8",
      "application/json; charset=utf-8",
      "application/json; charset=utf-8"
    ], @s3_client.puts.map { |put| put.fetch(:content_type) }
    assert_equal [
      "public, max-age=31536000, immutable",
      "public, max-age=31536000, immutable",
      "public, max-age=31536000, immutable",
      "no-cache, max-age=0, must-revalidate"
    ], @s3_client.puts.map { |put| put.fetch(:cache_control) }
    assert_not_includes out.string, "austrian-rocks-#{'latest'}.pmtiles"
    assert_includes out.string, "maps/current.json"
  end

  test "fails when a style public HEAD check is not successful" do
    publisher = build_publisher(http_head: ->(uri) { FakeHeadResponse.new(uri.to_s.include?("-dark.json") ? 503 : 200) })

    error = assert_raises(MapTiles::BunnyPublisher::VerificationError) { publisher.publish }

    assert_includes error.message, "returned 503"
    assert_includes error.message, "https://cdn.example.test/styles/austrian-rocks-2026-06-07-dark.json"
    assert_equal 4, @s3_client.puts.length
  end

  test "fails when the manifest public HEAD check is not successful" do
    publisher = build_publisher(http_head: ->(uri) { FakeHeadResponse.new(uri.to_s.end_with?("current.json") ? 404 : 200) })

    error = assert_raises(MapTiles::BunnyPublisher::VerificationError) { publisher.publish }

    assert_includes error.message, "returned 404"
    assert_includes error.message, "https://cdn.example.test/maps/current.json"
    assert_equal 4, @s3_client.puts.length
  end

  test "does not leak credentials in upload errors" do
    leaking_client = FakeS3Client.new(error: Aws::S3::Errors::ServiceError.new(nil, "super-secret"))
    publisher = build_publisher(s3_client: leaking_client)

    error = assert_raises(MapTiles::BunnyPublisher::UploadError) { publisher.publish }

    assert_includes error.message, "Bunny map release upload failed"
    assert_not_includes error.message, "super-secret"
  end

  private

  def build_publisher(
    configuration: @configuration,
    s3_client: @s3_client,
    http_head: @http_head,
    out: StringIO.new,
    style_materializer: @style_materializer,
    release_manifest: @release_manifest
  )
    MapTiles::BunnyPublisher.new(
      configuration: configuration,
      s3_client: s3_client,
      http_head: http_head,
      out: out,
      style_materializer: style_materializer,
      release_manifest: release_manifest
    )
  end

  def publication_env
    {
      "MAP_TILES_PUBLIC_CDN_HOST" => "https://legacy.example.test/",
      "MAP_TILES_BUNNY_PREFIX" => "/legacy/",
      "MAP_TILES_OUTPUT_DIR" => "tmp/legacy_map_tiles",
      "MAP_TILES_VERSION" => "legacy-version",
      "BUNNY_STORAGE_ENDPOINT" => "https://storage.example.test",
      "BUNNY_STORAGE_REGION" => "de",
      "BUNNY_STORAGE_BUCKET" => "austrian-rocks",
      "BUNNY_STORAGE_ACCESS_KEY_ID" => "key-id",
      "BUNNY_STORAGE_SECRET_ACCESS_KEY" => "super-secret"
    }
  end

  def map_tile_settings(overrides = {})
    {
      "artifact_basename" => "austrian-rocks",
      "output_dir" => @output_dir.to_s,
      "public_cdn_host" => "https://cdn.example.test/",
      "bunny_prefix" => "/maps/",
      "style_prefix" => "styles",
      "manifest_prefix" => "maps",
      "manifest_object_name" => "current.json",
      "default_style" => "light",
      "basemap_at_style_url" => "https://mapsneu.wien.gv.at/basemapvectorneu/root.json",
      "basemap_at_attribution" => "Grundkarte: <a href=\"https://basemap.at/\" target=\"_blank\" rel=\"noopener noreferrer\">basemap.at</a>",
      "terrain_opacity" => 0.35,
      "optional_production_layers" => []
    }.merge(overrides)
  end

  class FakeStyleMaterializer
    attr_reader :called

    def initialize(configuration)
      @configuration = configuration
      @called = false
    end

    def materialize
      @called = true
      MapTiles::Configuration::STYLE_NAMES.to_h do |style_name|
        path = @configuration.style_artifact_path(style_name)
        FileUtils.mkdir_p(path.dirname)
        path.write("{\"style\":\"#{style_name}\"}")
        [ style_name, path ]
      end
    end
  end

  class FakeReleaseManifest
    attr_reader :called

    def initialize(configuration)
      @configuration = configuration
      @called = false
    end

    def write
      @called = true
      path = @configuration.manifest_artifact_path
      FileUtils.mkdir_p(path.dirname)
      path.write("{\"version\":\"#{@configuration.version}\"}")
      path
    end
  end

  class FakeS3Client
    attr_reader :puts

    def initialize(error: nil)
      @error = error
      @puts = []
    end

    def put_object(bucket:, key:, body:, content_type:, cache_control:)
      raise @error if @error

      @puts << {
        bucket: bucket,
        key: key,
        body: body.read,
        content_type: content_type,
        cache_control: cache_control
      }
    end
  end

  class FakeHeadResponse
    attr_reader :code

    def initialize(code)
      @code = code.to_s
    end
  end
end
