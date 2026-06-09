# frozen_string_literal: true

require "test_helper"

class Admin::ExportsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    clear_enqueued_jobs
    clear_performed_jobs
    MapTilePublishState.delete_all
    MapTilePublishAttempt.delete_all
  end

  teardown do
    clear_enqueued_jobs
    clear_performed_jobs
  end

  test "index renders SQLite export and PMTiles publish controls" do
    get admin_exports_path(locale: :en)

    assert_response :success
    assert_includes response.body, "SQLite Database"
    assert_includes response.body, "PMTiles publishing"
    assert_includes response.body, "Publish now"
    assert_includes response.body, "Build, smoke-check, and publish PMTiles now?"
    assert_includes response.body, "up to date"
  end

  test "index renders PMTiles status, last success, pending publish, history, and sanitized errors" do
    freeze_time do
      successful = MapTilePublishAttempt.create!(
        source: "manual",
        status: "succeeded",
        trigger_reason: "Manual admin publish",
        version: "2026-06-08T16-45-30Z",
        scheduled_for: 20.minutes.ago,
        enqueued_at: 20.minutes.ago,
        started_at: 19.minutes.ago,
        finished_at: 18.minutes.ago,
        pmtiles_url: "https://cdn.example.test/map_tiles/austrian-rocks-2026-06-08T16-45-30Z.pmtiles",
        manifest_url: "https://cdn.example.test/map_tiles/current.json"
      )
      pending = MapTilePublishAttempt.create!(
        source: "automatic",
        status: "pending",
        trigger_reason: "Problem#123 changed",
        scheduled_for: 30.minutes.from_now,
        enqueued_at: Time.current
      )
      failed = MapTilePublishAttempt.create!(
        source: "automatic",
        status: "failed",
        trigger_reason: "Boulder#9 changed",
        error_text: "BUNNY_STORAGE_SECRET_ACCESS_KEY=#{ENV.fetch("BUNNY_STORAGE_SECRET_ACCESS_KEY")}",
        created_at: 1.minute.ago,
        finished_at: 1.minute.ago
      )
      MapTilePublishState.current!.update!(
        last_successful_attempt: successful,
        pending_automatic_attempt: pending,
        last_failed_attempt: failed,
        last_source_change_at: Time.current
      )

      get admin_exports_path(locale: :en)
    end

    assert_response :success
    assert_includes response.body, "pending"
    assert_includes response.body, "2026-06-08T16-45-30Z"
    assert_includes response.body, "https://cdn.example.test/map_tiles/austrian-rocks-2026-06-08T16-45-30Z.pmtiles"
    assert_includes response.body, "https://cdn.example.test/map_tiles/current.json"
    assert_includes response.body, "Problem#123 changed"
    assert_includes response.body, "Boulder#9 changed"
    assert_includes response.body, "[REDACTED BUNNY_STORAGE_SECRET_ACCESS_KEY]"
    assert_not_includes response.body, ENV.fetch("BUNNY_STORAGE_SECRET_ACCESS_KEY")
  end

  test "SQLite DB download remains available" do
    with_app_db_exporter_stub do
      get db_admin_exports_path(locale: :en, format: :db)
    end

    assert_response :success
    assert_equal "application/x-sqlite3", response.media_type
    assert_includes response.headers.fetch("Content-Disposition"), "austrian-rocks.db"
    assert_equal "stub sqlite database", response.body
  end

  test "manual PMTiles publish enqueues one job without running the pipeline" do
    fake_pipeline = Object.new
    fake_pipeline.define_singleton_method(:call) { |_attempt| flunk "controller must not run publish pipeline" }

    with_pipeline_stub(fake_pipeline) do
      assert_difference "MapTilePublishAttempt.count", 1 do
        assert_enqueued_with(job: MapTilePublishJob) do
          post publish_pmtiles_admin_exports_path(locale: :en)
        end
      end
    end

    attempt = MapTilePublishAttempt.order(:created_at).last
    assert_redirected_to admin_exports_path(locale: :en)
    assert_equal "manual", attempt.source
    assert_equal "pending", attempt.status
    assert_equal "Manual admin publish", attempt.trigger_reason
  end

  test "legacy GeoJSON export controls are absent" do
    get admin_exports_path(locale: :en)

    assert_response :success
    assert_not_includes response.body, "areas.geojson"
    assert_not_includes response.body, "clusters.geojson"
    assert_not_includes response.body, "regions.geojson"
    assert_not_includes response.body, "problems.geojson"
    assert_not_includes response.body, "Include boulders"
  end

  test "legacy GeoJSON route helpers are removed while DB helper remains" do
    assert_raises(NoMethodError) { areas_geojson_admin_exports_path(locale: :en) }
    assert_raises(NoMethodError) { clusters_geojson_admin_exports_path(locale: :en) }
    assert_raises(NoMethodError) { regions_geojson_admin_exports_path(locale: :en) }
    assert_raises(NoMethodError) { problems_geojson_admin_exports_path(locale: :en) }

    assert_equal "/en/admin/exports/db", db_admin_exports_path(locale: :en)
  end

  test "legacy GeoJSON requests are not routable" do
    get "/en/admin/exports/areas_geojson"
    assert_response :not_found

    get "/en/admin/exports/clusters_geojson"
    assert_response :not_found

    get "/en/admin/exports/regions_geojson"
    assert_response :not_found

    get "/en/admin/exports/problems_geojson"
    assert_response :not_found
  end

  private

  def with_app_db_exporter_stub
    original_call = AppDbExporter.method(:call)
    AppDbExporter.define_singleton_method(:call) do |path|
      File.write(path, "stub sqlite database")
    end
    yield
  ensure
    AppDbExporter.define_singleton_method(:call, &original_call)
  end

  def with_pipeline_stub(fake_pipeline)
    original_new = MapTiles::PublishPipeline.method(:new)
    MapTiles::PublishPipeline.define_singleton_method(:new) { |**_args| fake_pipeline }
    yield
  ensure
    MapTiles::PublishPipeline.define_singleton_method(:new, &original_new)
  end
end
