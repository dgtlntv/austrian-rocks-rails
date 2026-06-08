# frozen_string_literal: true

require "test_helper"

class MapTilePublishJobTest < ActiveJob::TestCase
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

  test "claims a pending attempt before running the pipeline" do
    attempt = MapTilePublishAttempt.create!(source: "manual", status: "pending")
    called = false
    claimed_status = nil
    running_attempt_id = nil
    fake_pipeline = Object.new
    fake_pipeline.define_singleton_method(:call) do |claimed_attempt|
      called = true
      claimed_attempt.reload
      claimed_status = claimed_attempt.status
      running_attempt_id = MapTilePublishState.current!.running_attempt_id
    end

    with_pipeline_stub(fake_pipeline) do
      MapTilePublishJob.perform_now(attempt.id)
    end

    assert called
    assert_equal "running", claimed_status
    assert_equal attempt.id, running_attempt_id
    assert_equal "running", attempt.reload.status
  end

  test "early automatic attempts self reschedule without running the pipeline" do
    freeze_time do
      attempt = MapTilePublishAttempt.create!(
        source: "automatic",
        status: "pending",
        scheduled_for: 10.minutes.from_now
      )
      MapTilePublishState.current!.update!(pending_automatic_attempt: attempt)
      fake_pipeline = Object.new
      fake_pipeline.define_singleton_method(:call) { |_attempt| flunk "pipeline should not run" }

      with_pipeline_stub(fake_pipeline) do
        assert_enqueued_with(job: MapTilePublishJob) do
          MapTilePublishJob.perform_now(attempt.id)
        end
      end

      assert_equal "pending", attempt.reload.status
      assert_equal attempt.id, MapTilePublishState.current!.pending_automatic_attempt_id
    end
  end

  test "manual attempts are cancelled when another publish is running" do
    freeze_time do
      running = MapTilePublishAttempt.create!(source: "automatic", status: "running")
      MapTilePublishState.current!.update!(running_attempt: running)
      attempt = MapTilePublishAttempt.create!(source: "manual", status: "pending")

      MapTilePublishJob.perform_now(attempt.id)

      attempt.reload
      assert_equal "cancelled", attempt.status
      assert_equal "Another PMTiles publish is already running", attempt.error_text
      assert_equal Time.current, attempt.finished_at
      assert_equal running.id, MapTilePublishState.current!.running_attempt_id
    end
  end

  test "automatic attempts remain pending and requeue when another publish is running" do
    freeze_time do
      running = MapTilePublishAttempt.create!(source: "manual", status: "running")
      state = MapTilePublishState.current!
      attempt = MapTilePublishAttempt.create!(
        source: "automatic",
        status: "pending",
        scheduled_for: 1.minute.ago
      )
      state.update!(running_attempt: running, pending_automatic_attempt: attempt)

      assert_enqueued_with(job: MapTilePublishJob) do
        MapTilePublishJob.perform_now(attempt.id)
      end

      attempt.reload
      assert_equal "pending", attempt.status
      assert_in_delta 30.minutes.from_now.to_f, attempt.scheduled_for.to_f, 1.0
      assert_equal running.id, state.reload.running_attempt_id
      assert_equal attempt.id, state.pending_automatic_attempt_id
    end
  end

  test "scheduler default enqueues the real publish job without running the pipeline" do
    fake_pipeline = Object.new
    fake_pipeline.define_singleton_method(:call) { |_attempt| flunk "manual scheduling must not run the pipeline" }

    with_pipeline_stub(fake_pipeline) do
      assert_enqueued_with(job: MapTilePublishJob) do
        MapTiles::PublishScheduler.new.enqueue_manual!(reason: "Manual admin publish")
      end
    end

    assert_equal 1, MapTilePublishAttempt.where(source: "manual", status: "pending").count
  end

  private

  def with_pipeline_stub(fake_pipeline)
    original_new = MapTiles::PublishPipeline.method(:new)
    MapTiles::PublishPipeline.define_singleton_method(:new) { |**_args| fake_pipeline }
    yield
  ensure
    MapTiles::PublishPipeline.define_singleton_method(:new, &original_new)
  end
end
