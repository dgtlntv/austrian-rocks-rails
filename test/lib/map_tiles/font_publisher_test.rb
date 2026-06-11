# frozen_string_literal: true

require "test_helper"
require "securerandom"
require "stringio"
require "map_tiles/font_publisher"

class MapTiles::FontPublisherTest < ActiveSupport::TestCase
  setup do
    @font_version = "font-publisher-test-#{SecureRandom.hex(8)}"
    @font_subpath = "fonts/#{@font_version}"
    @configuration = MapTiles::Configuration.new(env: publication_env, settings: map_tile_settings)
    @font_root = @configuration.font_glyph_root
    @outside_dir = Rails.root.join("tmp/font_publisher_test/#{@font_version}")
    @s3_client = FakeS3Client.new
  end

  teardown do
    FileUtils.rm_rf(@font_root)
    FileUtils.rm_rf(@outside_dir)
  end

  test "uploads sorted PBF objects with stable keys, bodies, and immutable headers" do
    write_pbf("Inter Regular/256-511.pbf", "regular-256")
    write_pbf("Inter Bold/0-255.pbf", "bold-0")
    write_pbf("Inter Regular/0-255.pbf", "regular-0")
    out = StringIO.new
    publisher = build_publisher(out: out)

    published = publisher.publish
    first_uploads = @s3_client.puts.dup
    publisher.publish
    second_uploads = @s3_client.puts.drop(first_uploads.length)

    expected_keys = [
      "map_styles/fonts/#{@font_version}/Inter Bold/0-255.pbf",
      "map_styles/fonts/#{@font_version}/Inter Regular/0-255.pbf",
      "map_styles/fonts/#{@font_version}/Inter Regular/256-511.pbf"
    ]
    assert_equal expected_keys, first_uploads.map { |put| put.fetch(:key) }
    assert_equal first_uploads, second_uploads
    assert_equal expected_keys, published.map { |object| object.fetch(:key) }
    assert_equal [ "bold-0", "regular-0", "regular-256" ], first_uploads.map { |put| put.fetch(:body) }
    assert_equal [ "application/x-protobuf" ] * 3, first_uploads.map { |put| put.fetch(:content_type) }
    assert_equal [ "public, max-age=31536000, immutable" ] * 3, first_uploads.map { |put| put.fetch(:cache_control) }
    assert_includes out.string, "map_styles/fonts/#{@font_version}/Inter Regular/0-255.pbf"
    assert_includes out.string, "Inter%20Regular/0-255.pbf"
  end

  test "requires Bunny env, a style prefix, an existing root, and at least one PBF" do
    missing_env_configuration = MapTiles::Configuration.new(
      env: publication_env.except("BUNNY_STORAGE_SECRET_ACCESS_KEY"),
      settings: map_tile_settings
    )
    missing_env = assert_raises(MapTiles::FontPublisher::ConfigurationError) do
      build_publisher(configuration: missing_env_configuration).publish
    end
    assert_includes missing_env.message, "BUNNY_STORAGE_SECRET_ACCESS_KEY"
    assert_not_includes missing_env.message, "super-secret"

    blank_style_configuration = MapTiles::Configuration.new(
      env: publication_env,
      settings: map_tile_settings("style_prefix" => "")
    )
    blank_style = assert_raises(MapTiles::FontPublisher::ConfigurationError) do
      build_publisher(configuration: blank_style_configuration).publish
    end
    assert_includes blank_style.message, "Configured style prefix"

    missing_root = assert_raises(MapTiles::FontPublisher::ConfigurationError) { build_publisher.publish }
    assert_includes missing_root.message, "Configured font glyph root is missing"

    FileUtils.mkdir_p(@font_root)
    @font_root.join("README.md").write("docs only")
    empty_root = assert_raises(MapTiles::FontPublisher::ConfigurationError) { build_publisher.publish }
    assert_includes empty_root.message, "contains no PBF files"
  end

  test "rejects escaped symlink and unsafe object-key segments" do
    FileUtils.mkdir_p(@outside_dir)
    outside_pbf = @outside_dir.join("0-255.pbf")
    outside_pbf.binwrite("outside")
    FileUtils.mkdir_p(@font_root.join("Inter Regular"))
    File.symlink(outside_pbf, @font_root.join("Inter Regular/0-255.pbf"))

    escaped = assert_raises(MapTiles::FontPublisher::ConfigurationError) { build_publisher.publish }
    assert_includes escaped.message, "escapes configured root"

    FileUtils.rm_rf(@font_root)
    write_pbf("Inter:Regular/0-255.pbf", "unsafe")
    unsafe = assert_raises(MapTiles::FontPublisher::ConfigurationError) { build_publisher.publish }
    assert_includes unsafe.message, "unsafe characters"
  rescue NotImplementedError, SystemCallError
    skip "symlinks are unavailable on this filesystem"
  end

  test "does not leak credentials or raw service errors when upload fails" do
    write_pbf("Inter Regular/0-255.pbf", "regular")
    leaking_client = FakeS3Client.new(error: Aws::S3::Errors::ServiceError.new(nil, "super-secret"))
    publisher = build_publisher(s3_client: leaking_client)

    error = assert_raises(MapTiles::FontPublisher::UploadError) { publisher.publish }

    assert_includes error.message, "Bunny font glyph upload failed"
    assert_includes error.message, "map_styles/fonts/#{@font_version}/Inter Regular/0-255.pbf"
    assert_not_includes error.message, "super-secret"
  end

  private

  def build_publisher(configuration: @configuration, s3_client: @s3_client, out: StringIO.new)
    MapTiles::FontPublisher.new(configuration: configuration, s3_client: s3_client, out: out)
  end

  def write_pbf(relative_path, body)
    path = @font_root.join(relative_path)
    FileUtils.mkdir_p(path.dirname)
    path.binwrite(body)
  end

  def publication_env
    {
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
      "output_dir" => "tmp/font_publisher_test_output/#{@font_version}",
      "public_cdn_host" => "https://cdn.example.test/",
      "bunny_prefix" => "maps",
      "style_prefix" => "map_styles",
      "font_glyph_subpath" => @font_subpath,
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
    }.merge(overrides)
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
end
