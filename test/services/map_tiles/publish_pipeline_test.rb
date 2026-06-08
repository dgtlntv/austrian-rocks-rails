# frozen_string_literal: true

require "test_helper"

class MapTiles::PublishPipelineTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    clear_enqueued_jobs
    clear_performed_jobs
    MapTilePublishState.delete_all
    MapTilePublishAttempt.delete_all
    @original_skip_smoke = ENV["MAP_TILES_SKIP_SMOKE"]
  end

  teardown do
    ENV["MAP_TILES_SKIP_SMOKE"] = @original_skip_smoke
    clear_enqueued_jobs
    clear_performed_jobs
  end

  test "runs collaborators in order, records URLs, and cleans after success" do
    ENV["MAP_TILES_SKIP_SMOKE"] = "1"
    calls = []
    collaborators = successful_collaborators(calls)
    attempt = running_attempt(started_at: Time.zone.parse("2026-06-08 16:45:00 UTC"))
    clock_time = Time.new(2026, 6, 8, 18, 45, 30, "+02:00")

    pipeline = MapTiles::PublishPipeline.new(**collaborators, clock: -> { clock_time })
    pipeline.call(attempt)

    assert_equal %i[export build smoke publish clean], calls.map(&:first)
    assert_equal [ "--mode=production" ], calls.find { |call| call.first == :smoke }.third

    attempt.reload
    assert_equal "succeeded", attempt.status
    assert_equal "2026-06-08T16-45-30Z", attempt.version
    assert_equal "https://tiles.example/map_tiles/test/austrian-rocks-2026-06-08T16-45-30Z.pmtiles", attempt.pmtiles_url
    assert_equal "https://tiles.example/map_tiles/test/austrian-rocks-latest.json", attempt.manifest_url
    assert_equal "map_tiles/test/austrian-rocks-2026-06-08T16-45-30Z.pmtiles", attempt.pmtiles_object_key
    assert_equal "map_tiles/test/austrian-rocks-latest.json", attempt.manifest_object_key
    assert_equal attempt.id, MapTilePublishState.current!.last_successful_attempt_id
    assert_nil MapTilePublishState.current!.running_attempt_id
  end

  test "clears stale state only when no newer source edit exists" do
    calls = []
    collaborators = successful_collaborators(calls)
    started_at = Time.zone.parse("2026-06-08 16:00:00 UTC")
    attempt = running_attempt(started_at: started_at)
    MapTilePublishState.current!.update!(stale_at: started_at - 1.minute)

    MapTiles::PublishPipeline.new(**collaborators, clock: -> { started_at + 5.minutes }).call(attempt)

    assert_nil MapTilePublishState.current!.reload.stale_at
  end

  test "keeps newer stale state and enqueues an automatic follow-up" do
    calls = []
    collaborators = successful_collaborators(calls)
    started_at = Time.zone.parse("2026-06-08 16:00:00 UTC")
    attempt = running_attempt(started_at: started_at)
    MapTilePublishState.current!.update!(stale_at: started_at + 2.minutes, last_source_change_at: started_at + 2.minutes)

    assert_enqueued_with(job: MapTilePublishJob) do
      MapTiles::PublishPipeline.new(**collaborators, clock: -> { started_at + 5.minutes }).call(attempt)
    end

    state = MapTilePublishState.current!.reload
    assert_equal started_at + 2.minutes, state.stale_at
    assert_predicate state.pending_automatic_attempt, :present?
    assert_equal "automatic", state.pending_automatic_attempt.source
    assert_equal "pending", state.pending_automatic_attempt.status
    assert_equal started_at + 32.minutes, state.pending_automatic_attempt.scheduled_for
  end

  test "records sanitized failures and clears running state" do
    ENV["BUNNY_STORAGE_SECRET_ACCESS_KEY"] = "super-secret-token"
    error = MapTiles::BunnyPublisher::UploadError.new("provider exposed super-secret-token in body")
    calls = []
    collaborators = failing_collaborators(calls, error: error, at: :publish)
    attempt = running_attempt(started_at: Time.zone.parse("2026-06-08 16:00:00 UTC"))

    MapTiles::PublishPipeline.new(**collaborators, clock: -> { Time.zone.parse("2026-06-08 16:10:00 UTC") }).call(attempt)

    attempt.reload
    assert_equal "failed", attempt.status
    assert_includes attempt.error_text, "[REDACTED VALUE]"
    assert_not_includes attempt.error_text, "super-secret-token"
    assert_equal attempt.id, MapTilePublishState.current!.last_failed_attempt_id
    assert_nil MapTilePublishState.current!.running_attempt_id
  end

  test "rescues major pipeline failure classes" do
    failures = [
      MapTiles::TippecanoeBuilder::MissingExecutableError.new("missing tippecanoe"),
      MapTiles::TippecanoeBuilder::BuildError.new("build failed"),
      MapTiles::SmokeCheck::Error.new("smoke failed"),
      MapTiles::BunnyPublisher::ConfigurationError.new("missing bunny configuration"),
      MapTiles::BunnyPublisher::VerificationError.new("manifest verification failed"),
      StandardError.new("unexpected failure")
    ]

    failures.each do |error|
      MapTilePublishAttempt.delete_all
      MapTilePublishState.delete_all
      calls = []
      collaborators = failing_collaborators(calls, error: error, at: failure_stage(error))
      attempt = running_attempt(started_at: Time.zone.parse("2026-06-08 16:00:00 UTC"))

      MapTiles::PublishPipeline.new(**collaborators, clock: -> { Time.zone.parse("2026-06-08 16:05:00 UTC") }).call(attempt)

      assert_equal "failed", attempt.reload.status, "#{error.class} should fail the attempt"
      assert_equal attempt.id, MapTilePublishState.current!.last_failed_attempt_id
    end
  end

  private

  def running_attempt(started_at:)
    attempt = MapTilePublishAttempt.create!(source: "manual", status: "running", started_at: started_at)
    MapTilePublishState.current!.update!(running_attempt: attempt)
    attempt
  end

  def configuration
    MapTiles::Configuration.new(settings: {
      "artifact_basename" => "austrian-rocks",
      "output_dir" => "tmp/map_tiles",
      "public_cdn_host" => "tiles.example",
      "bunny_prefix" => "map_tiles/test",
      "optional_production_layers" => [],
      "automatic_publish_debounce_minutes" => 30,
      "manifest_cache_ttl_seconds" => 60,
      "pmtiles_cache_control" => "public, max-age=31536000, immutable",
      "manifest_content_type" => "application/json"
    })
  end

  def successful_collaborators(calls)
    {
      configuration: configuration,
      exporter_class: exporter_class(calls),
      builder_class: builder_class(calls),
      smoke_check_class: smoke_check_class(calls),
      publisher_class: publisher_class(calls),
      cleaner_class: cleaner_class(calls)
    }
  end

  def failing_collaborators(calls, error:, at:)
    {
      configuration: configuration,
      exporter_class: exporter_class(calls, error: at == :export ? error : nil),
      builder_class: builder_class(calls, error: at == :build ? error : nil),
      smoke_check_class: smoke_check_class(calls, error: at == :smoke ? error : nil),
      publisher_class: publisher_class(calls, error: at == :publish ? error : nil),
      cleaner_class: cleaner_class(calls, error: at == :clean ? error : nil)
    }
  end

  def exporter_class(calls, error: nil)
    Class.new do
      define_method(:initialize) { |configuration:| @configuration = configuration }
      define_method(:export) do
        raise error if error

        calls << [ :export, @configuration.version ]
        { "problems" => Rails.root.join("tmp/problems.geojson") }
      end
    end
  end

  def builder_class(calls, error: nil)
    Class.new do
      define_method(:initialize) { |configuration:| @configuration = configuration }
      define_method(:build) do |layer_paths:|
        raise error if error

        calls << [ :build, @configuration.version, layer_paths ]
        @configuration.artifact_path
      end
    end
  end

  def smoke_check_class(calls, error: nil)
    Class.new do
      define_method(:initialize) do |configuration:, argv:|
        @configuration = configuration
        @argv = argv
      end
      define_method(:run) do
        raise error if error

        calls << [ :smoke, @configuration.version, @argv ]
        true
      end
    end
  end

  def publisher_class(calls, error: nil)
    Class.new do
      define_method(:initialize) { |configuration:| @configuration = configuration }
      define_method(:publish) do
        raise error if error

        calls << [ :publish, @configuration.version ]
        {
          pmtiles: {
            key: @configuration.versioned_object_key,
            url: "https://tiles.example/#{@configuration.versioned_object_key}"
          },
          manifest: {
            key: @configuration.latest_manifest_object_key,
            url: "https://tiles.example/#{@configuration.latest_manifest_object_key}"
          }
        }
      end
    end
  end

  def cleaner_class(calls, error: nil)
    Class.new do
      define_method(:initialize) { |configuration:| @configuration = configuration }
      define_method(:clean) do
        raise error if error

        calls << [ :clean, @configuration.version ]
        []
      end
    end
  end

  def failure_stage(error)
    case error
    when MapTiles::SmokeCheck::Error
      :smoke
    when MapTiles::BunnyPublisher::Error
      :publish
    when StandardError
      :build
    end
  end
end
