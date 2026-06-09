# frozen_string_literal: true

require "test_helper"

class MapTiles::PublishSchedulerTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  # Stub job class for testing scheduler enqueue behavior.
  # MapTilePublishJob is defined in Phase P3; we use this stub
  # so scheduler tests work independently of the job implementation.
  class StubPublishJob < ApplicationJob
    def perform(attempt_id)
      # no-op: scheduler tests only verify enqueue behavior
    end
  end

  setup do
    @scheduler = MapTiles::PublishScheduler.new(publish_job_class: StubPublishJob)
  end

  teardown do
    clear_enqueued_jobs
  end

  # -- enqueue_manual! -------------------------------------------------------

  test "enqueue_manual! creates a manual pending attempt" do
    attempt = @scheduler.enqueue_manual!(reason: "Admin clicked publish")

    assert_equal "manual", attempt.source
    assert_equal "pending", attempt.status
    assert_equal "Admin clicked publish", attempt.trigger_reason
    assert_predicate attempt.scheduled_for, :present?
    assert_predicate attempt.enqueued_at, :present?
  end

  test "enqueue_manual! enqueues a job immediately" do
    assert_enqueued_with(job: StubPublishJob) do
      @scheduler.enqueue_manual!(reason: "Admin clicked publish")
    end
  end

  test "enqueue_manual! uses custom at time" do
    freeze_time do
      attempt = @scheduler.enqueue_manual!(reason: "Test", at: 5.minutes.from_now)

      assert_equal 5.minutes.from_now, attempt.scheduled_for
      assert_equal 5.minutes.from_now, attempt.enqueued_at
    end
  end

  # -- mark_stale! -----------------------------------------------------------

  test "mark_stale! sets stale_at and last_source_change_at" do
    freeze_time do
      @scheduler.mark_stale!(reason: "Problem#1 changed")

      state = MapTilePublishState.current!
      assert_equal Time.current, state.stale_at
      assert_equal Time.current, state.last_source_change_at
    end
  end

  test "mark_stale! creates a pending automatic attempt when none exists" do
    @scheduler.mark_stale!(reason: "Area#5 changed")

    state = MapTilePublishState.current!
    assert_predicate state.pending_automatic_attempt, :present?
    assert_equal "automatic", state.pending_automatic_attempt.source
    assert_equal "pending", state.pending_automatic_attempt.status
    assert_equal "Area#5 changed", state.pending_automatic_attempt.trigger_reason
  end

  test "mark_stale! enqueues a delayed job" do
    assert_enqueued_with(job: StubPublishJob) do
      @scheduler.mark_stale!(reason: "Boulder#3 changed")
    end
  end

  test "mark_stale! enqueues job with wait_until" do
    freeze_time do
      @scheduler.mark_stale!(reason: "Test")

      job = enqueued_jobs.last
      assert_equal StubPublishJob, job[:job]
      wait_until_at = job[:at]
      assert wait_until_at.present?
      expected = 30.minutes.from_now.to_f
      assert_in_delta expected, wait_until_at, 1.0
    end
  end

  test "mark_stale! updates existing pending attempt on subsequent calls" do
    freeze_time do
      @scheduler.mark_stale!(reason: "First edit")

      state = MapTilePublishState.current!
      attempt_id = state.pending_automatic_attempt.id
      original_scheduled_for = state.pending_automatic_attempt.scheduled_for

      # Simulate an edit 5 minutes later
      travel 5.minutes
      @scheduler.mark_stale!(reason: "Second edit")

      state.reload
      assert_equal attempt_id, state.pending_automatic_attempt.id
      assert_not_equal original_scheduled_for, state.pending_automatic_attempt.scheduled_for
      assert_equal "Second edit", state.pending_automatic_attempt.trigger_reason
    end
  end

  test "mark_stale! slides scheduled_for forward on repeated edits" do
    freeze_time do
      @scheduler.mark_stale!(reason: "Edit 1")

      first_scheduled = MapTilePublishState.current!.pending_automatic_attempt.scheduled_for

      travel 10.minutes
      @scheduler.mark_stale!(reason: "Edit 2")

      second_scheduled = MapTilePublishState.current!.pending_automatic_attempt.scheduled_for

      # second_scheduled should be approximately 10 minutes later than first_scheduled
      # (because the base time moved forward 10 minutes)
      assert_in_delta first_scheduled + 10.minutes, second_scheduled, 1.0
    end
  end

  test "mark_stale! maintains exactly one pending automatic attempt after multiple edits" do
    @scheduler.mark_stale!(reason: "Edit 1")
    @scheduler.mark_stale!(reason: "Edit 2")
    @scheduler.mark_stale!(reason: "Edit 3")

    pending_count = MapTilePublishAttempt.where(
      source: "automatic",
      status: "pending"
    ).count
    assert_equal 1, pending_count
  end

  test "mark_stale! preserves running attempt while creating pending follow-up" do
    state = MapTilePublishState.current!
    running = MapTilePublishAttempt.create!(source: "manual", status: "running")
    state.update!(running_attempt: running)

    @scheduler.mark_stale!(reason: "Edit during publish")

    state.reload
    assert_equal running.id, state.running_attempt_id
    assert_predicate state.pending_automatic_attempt, :present?
    assert_equal "Edit during publish", state.pending_automatic_attempt.trigger_reason
  end

  test "mark_stale! updates existing pending attempt when a publish is running" do
    state = MapTilePublishState.current!
    running = MapTilePublishAttempt.create!(source: "manual", status: "running")
    state.update!(running_attempt: running)

    @scheduler.mark_stale!(reason: "Edit during publish 1")
    pending_id = state.reload.pending_automatic_attempt.id

    @scheduler.mark_stale!(reason: "Edit during publish 2")

    state.reload
    assert_equal pending_id, state.pending_automatic_attempt.id
    assert_equal "Edit during publish 2", state.pending_automatic_attempt.trigger_reason
  end

  test "mark_stale! uses custom configuration debounce" do
    # Build a configuration with a custom debounce duration by using
    # a test double that responds to automatic_publish_debounce.
    config = OpenStruct.new(automatic_publish_debounce: 15.minutes)
    scheduler = MapTiles::PublishScheduler.new(configuration: config, publish_job_class: StubPublishJob)

    freeze_time do
      scheduler.mark_stale!(reason: "Test with custom debounce")

      job = enqueued_jobs.last
      expected = 15.minutes.from_now.to_f
      assert_in_delta expected, job[:at], 1.0
    end
  end

  # -- outside production ---------------------------------------------------

  test "scheduler works directly outside production (no Rails.env guard here)" do
    # The scheduler itself has no Rails.env guard — that's in the concern.
    # This test proves direct service calls work regardless of environment.
    @scheduler.mark_stale!(reason: "Direct call test")

    state = MapTilePublishState.current!
    assert_predicate state.stale_at, :present?
    assert_predicate state.pending_automatic_attempt, :present?
  end
end
