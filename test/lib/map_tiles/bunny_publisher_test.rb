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
    publisher = MapTiles::BunnyPublisher.new(configuration: configuration, s3_client: @s3_client, http_head: @http_head)

    error = assert_raises(MapTiles::BunnyPublisher::ConfigurationError) { publisher.publish }

    assert_includes error.message, "BUNNY_STORAGE_SECRET_ACCESS_KEY"
    assert_not_includes error.message, "MAP_TILES_PUBLIC_CDN_HOST"
    assert_not_includes error.message, "super-secret"
  end

  test "requires config-backed publication settings" do
    configuration = MapTiles::Configuration.new(version: "2026-06-07", env: @env, settings: map_tile_settings("public_cdn_host" => ""))
    publisher = MapTiles::BunnyPublisher.new(configuration: configuration, s3_client: @s3_client, http_head: @http_head)

    error = assert_raises(MapTiles::BunnyPublisher::ConfigurationError) { publisher.publish }

    assert_includes error.message, "Configured public CDN host is required"
    assert_not_includes error.message, "MAP_TILES_PUBLIC_CDN_HOST"
  end

  test "constructs sanitized versioned and latest manifest object keys" do
    assert_equal "maps/austrian-rocks-2026-06-07.pmtiles", @configuration.versioned_object_key
    assert_equal "maps/austrian-rocks-latest.json", @configuration.latest_manifest_object_key
    assert_equal "maps/austrian-rocks-latest.pmtiles", @configuration.latest_object_key

    bad_configuration = MapTiles::Configuration.new(version: "2026/06/07", env: @env, settings: map_tile_settings)

    assert_raises(ArgumentError) { bad_configuration.versioned_object_key }

    blank_prefix_configuration = MapTiles::Configuration.new(version: "2026-06-07", env: @env, settings: map_tile_settings("bunny_prefix" => "/"))
    publisher = MapTiles::BunnyPublisher.new(configuration: blank_prefix_configuration, s3_client: @s3_client, http_head: @http_head)

    error = assert_raises(MapTiles::BunnyPublisher::ConfigurationError) { publisher.publish }
    assert_includes error.message, "Configured Bunny prefix"
  end

  test "uploads immutable PMTiles and latest manifest and verifies both public urls" do
    out = StringIO.new
    publisher = MapTiles::BunnyPublisher.new(
      configuration: @configuration,
      s3_client: @s3_client,
      http_head: @http_head,
      out: out,
      clock: -> { Time.utc(2026, 6, 8, 16, 45, 30) }
    )

    published = publisher.publish

    assert_equal %w[maps/austrian-rocks-2026-06-07.pmtiles maps/austrian-rocks-latest.json], @s3_client.puts.map { |put| put.fetch(:key) }
    assert_equal [ "https://cdn.example.test/maps/austrian-rocks-2026-06-07.pmtiles", "https://cdn.example.test/maps/austrian-rocks-latest.json" ], @head_urls
    assert_equal "https://cdn.example.test/maps/austrian-rocks-2026-06-07.pmtiles", published.fetch(:pmtiles).fetch(:url)
    assert_equal "https://cdn.example.test/maps/austrian-rocks-latest.json", published.fetch(:manifest).fetch(:url)
    assert_equal "application/octet-stream", @s3_client.puts.first.fetch(:content_type)
    assert_equal "public, max-age=31536000, immutable", @s3_client.puts.first.fetch(:cache_control)
    assert_equal "application/json", @s3_client.puts.second.fetch(:content_type)
    assert_equal "public, max-age=60", @s3_client.puts.second.fetch(:cache_control)
    assert_equal "pmtiles", @s3_client.puts.first.fetch(:body)

    manifest = JSON.parse(@s3_client.puts.second.fetch(:body))
    assert_equal "2026-06-07", manifest.fetch("version")
    assert_equal "https://cdn.example.test/maps/austrian-rocks-2026-06-07.pmtiles", manifest.fetch("pmtiles_url")
    assert_equal "2026-06-08T16:45:30Z", manifest.fetch("published_at")
    assert_equal "austrian-rocks", manifest.fetch("artifact_basename")
    assert_equal "maps/austrian-rocks-2026-06-07.pmtiles", manifest.fetch("pmtiles_object_key")
    assert_equal "austrian-rocks-2026-06-07.pmtiles", manifest.fetch("pmtiles_object_basename")
    assert_includes out.string, "austrian-rocks-latest.json"
    assert_not_includes out.string, "austrian-rocks-latest.pmtiles"
  end

  test "latest manifest upload overwrites the stable object key" do
    MapTiles::BunnyPublisher.new(configuration: @configuration, s3_client: @s3_client, http_head: @http_head).publish
    MapTiles::BunnyPublisher.new(configuration: @configuration, s3_client: @s3_client, http_head: @http_head).publish

    latest_puts = @s3_client.puts.select { |put| put.fetch(:key) == "maps/austrian-rocks-latest.json" }
    latest_pmtiles_puts = @s3_client.puts.select { |put| put.fetch(:key) == "maps/austrian-rocks-latest.pmtiles" }

    assert_equal 2, latest_puts.length
    assert_empty latest_pmtiles_puts
  end

  test "fails when a public HEAD check is not successful" do
    publisher = MapTiles::BunnyPublisher.new(
      configuration: @configuration,
      s3_client: @s3_client,
      http_head: ->(_uri) { FakeHeadResponse.new(404) }
    )

    error = assert_raises(MapTiles::BunnyPublisher::VerificationError) { publisher.publish }

    assert_includes error.message, "returned 404"
    assert_includes error.message, "https://cdn.example.test/maps/austrian-rocks-2026-06-07.pmtiles"
    assert_equal %w[maps/austrian-rocks-2026-06-07.pmtiles], @s3_client.puts.map { |put| put.fetch(:key) }
  end

  test "fails when the manifest public HEAD check is not successful" do
    responses = [ FakeHeadResponse.new(200), FakeHeadResponse.new(404) ]
    publisher = MapTiles::BunnyPublisher.new(
      configuration: @configuration,
      s3_client: @s3_client,
      http_head: ->(_uri) { responses.shift }
    )

    error = assert_raises(MapTiles::BunnyPublisher::VerificationError) { publisher.publish }

    assert_includes error.message, "returned 404"
    assert_includes error.message, "https://cdn.example.test/maps/austrian-rocks-latest.json"
    assert_equal %w[maps/austrian-rocks-2026-06-07.pmtiles maps/austrian-rocks-latest.json], @s3_client.puts.map { |put| put.fetch(:key) }
  end

  test "does not leak credentials in upload errors" do
    leaking_client = FakeS3Client.new(error: Aws::S3::Errors::ServiceError.new(nil, "super-secret"))
    publisher = MapTiles::BunnyPublisher.new(configuration: @configuration, s3_client: leaking_client, http_head: @http_head)

    error = assert_raises(MapTiles::BunnyPublisher::UploadError) { publisher.publish }

    assert_includes error.message, "Bunny PMTiles upload failed"
    assert_not_includes error.message, "super-secret"
  end

  private

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

  class FakeHeadResponse
    attr_reader :code

    def initialize(code)
      @code = code.to_s
    end
  end
end
