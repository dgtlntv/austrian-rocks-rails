# frozen_string_literal: true

require "test_helper"
require "securerandom"
require "stringio"
require "map_tiles/bunny_publisher"

class MapTiles::BunnyPublisherTest < ActiveSupport::TestCase
  setup do
    @output_dir = Rails.root.join("tmp/bunny_publisher_test/#{SecureRandom.hex(8)}")
    @env = publication_env.merge("MAP_TILES_OUTPUT_DIR" => @output_dir.to_s)
    @configuration = MapTiles::Configuration.new(env: @env)
    FileUtils.mkdir_p(@configuration.output_dir)
    @configuration.artifact_path.binwrite("pmtiles")
    @s3_client = FakeS3Client.new
    @head_urls = []
    @http_head = ->(uri) { @head_urls << uri.to_s; FakeHeadResponse.new(200) }
  end

  teardown do
    FileUtils.rm_rf(@output_dir)
  end

  test "requires map and Bunny publication configuration" do
    configuration = MapTiles::Configuration.new(env: @env.except("MAP_TILES_PUBLIC_CDN_HOST", "BUNNY_STORAGE_SECRET_ACCESS_KEY"))
    publisher = MapTiles::BunnyPublisher.new(configuration: configuration, s3_client: @s3_client, http_head: @http_head)

    error = assert_raises(MapTiles::BunnyPublisher::ConfigurationError) { publisher.publish }

    assert_includes error.message, "MAP_TILES_PUBLIC_CDN_HOST"
    assert_includes error.message, "BUNNY_STORAGE_SECRET_ACCESS_KEY"
    assert_not_includes error.message, "super-secret"
  end

  test "constructs sanitized versioned and latest object keys" do
    assert_equal "maps/austrian-rocks-2026-06-07.pmtiles", @configuration.versioned_object_key
    assert_equal "maps/austrian-rocks-latest.pmtiles", @configuration.latest_object_key

    bad_configuration = MapTiles::Configuration.new(env: @env.merge("MAP_TILES_VERSION" => "2026/06/07"))

    assert_raises(ArgumentError) { bad_configuration.versioned_object_key }

    blank_prefix_configuration = MapTiles::Configuration.new(env: @env.merge("MAP_TILES_BUNNY_PREFIX" => "/"))
    publisher = MapTiles::BunnyPublisher.new(configuration: blank_prefix_configuration, s3_client: @s3_client, http_head: @http_head)

    error = assert_raises(MapTiles::BunnyPublisher::ConfigurationError) { publisher.publish }
    assert_includes error.message, "MAP_TILES_BUNNY_PREFIX"
  end

  test "uploads immutable and latest objects and verifies both public urls" do
    out = StringIO.new
    publisher = MapTiles::BunnyPublisher.new(
      configuration: @configuration,
      s3_client: @s3_client,
      http_head: @http_head,
      out: out
    )

    published = publisher.publish

    assert_equal %w[maps/austrian-rocks-2026-06-07.pmtiles maps/austrian-rocks-latest.pmtiles], @s3_client.puts.map { |put| put.fetch(:key) }
    assert_equal [ "https://cdn.example.test/maps/austrian-rocks-2026-06-07.pmtiles", "https://cdn.example.test/maps/austrian-rocks-latest.pmtiles" ], @head_urls
    assert_equal @head_urls, published.map { |object| object.fetch(:url) }
    assert @s3_client.puts.all? { |put| put.fetch(:content_type) == "application/octet-stream" }
    assert_includes out.string, "austrian-rocks-latest.pmtiles"
  end

  test "latest upload overwrites the stable object key" do
    MapTiles::BunnyPublisher.new(configuration: @configuration, s3_client: @s3_client, http_head: @http_head).publish
    MapTiles::BunnyPublisher.new(configuration: @configuration, s3_client: @s3_client, http_head: @http_head).publish

    latest_puts = @s3_client.puts.select { |put| put.fetch(:key) == "maps/austrian-rocks-latest.pmtiles" }

    assert_equal 2, latest_puts.length
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
    assert_equal %w[maps/austrian-rocks-2026-06-07.pmtiles maps/austrian-rocks-latest.pmtiles], @s3_client.puts.map { |put| put.fetch(:key) }
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
      "MAP_TILES_PUBLIC_CDN_HOST" => "https://cdn.example.test/",
      "MAP_TILES_BUNNY_PREFIX" => "/maps/",
      "MAP_TILES_VERSION" => "2026-06-07",
      "BUNNY_STORAGE_ENDPOINT" => "https://storage.example.test",
      "BUNNY_STORAGE_REGION" => "de",
      "BUNNY_STORAGE_BUCKET" => "austrian-rocks",
      "BUNNY_STORAGE_ACCESS_KEY_ID" => "key-id",
      "BUNNY_STORAGE_SECRET_ACCESS_KEY" => "super-secret"
    }
  end

  class FakeS3Client
    attr_reader :puts

    def initialize(error: nil)
      @error = error
      @puts = []
    end

    def put_object(bucket:, key:, body:, content_type:)
      raise @error if @error

      @puts << {
        bucket: bucket,
        key: key,
        body: body.read,
        content_type: content_type
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
