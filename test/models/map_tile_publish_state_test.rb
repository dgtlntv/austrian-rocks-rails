# frozen_string_literal: true

require "test_helper"

class MapTilePublishStateTest < ActiveSupport::TestCase
  test "current! creates singleton on first call" do
    assert_equal 0, MapTilePublishState.count

    state = MapTilePublishState.current!

    assert_equal 1, MapTilePublishState.count
    assert_predicate state, :persisted?
  end

  test "current! returns same row on subsequent calls" do
    first = MapTilePublishState.current!
    second = MapTilePublishState.current!

    assert_equal first.id, second.id
    assert_equal 1, MapTilePublishState.count
  end

  test "current_status is up_to_date when fresh with no errors" do
    state = MapTilePublishState.current!
    assert_equal "up_to_date", state.current_status
  end

  test "current_status is pending when a pending_automatic_attempt exists" do
    state = MapTilePublishState.current!
    attempt = MapTilePublishAttempt.create!(source: "automatic", status: "pending")
    state.update!(pending_automatic_attempt: attempt)

    assert_equal "pending", state.current_status
  end

  test "current_status is running when running_attempt is set" do
    state = MapTilePublishState.current!
    attempt = MapTilePublishAttempt.create!(source: "manual", status: "running")
    state.update!(running_attempt: attempt)

    assert_equal "running", state.current_status
  end

  test "current_status is failed when last attempt failed and no successful publish after" do
    state = MapTilePublishState.current!
    failed = MapTilePublishAttempt.create!(source: "automatic", status: "failed", finished_at: 1.minute.ago)
    state.update!(last_failed_attempt: failed, stale_at: 30.minutes.ago)

    assert_equal "failed", state.current_status
  end

  test "current_status is stale when source changed after last success" do
    state = MapTilePublishState.current!
    success = MapTilePublishAttempt.create!(source: "manual", status: "succeeded", finished_at: 1.hour.ago)
    state.update!(last_successful_attempt: success, stale_at: 30.minutes.ago)

    assert_equal "stale", state.current_status
  end

  test "current_status is up_to_date when last success is after stale_at" do
    state = MapTilePublishState.current!
    success = MapTilePublishAttempt.create!(source: "manual", status: "succeeded", finished_at: 1.minute.ago)
    state.update!(last_successful_attempt: success, stale_at: 30.minutes.ago)
    # stale_at is before finished_at, so data is up to date

    assert_equal "up_to_date", state.current_status
  end

  test "associations are optional" do
    state = MapTilePublishState.current!

    assert_nil state.pending_automatic_attempt
    assert_nil state.running_attempt
    assert_nil state.last_successful_attempt
    assert_nil state.last_failed_attempt
  end
end
