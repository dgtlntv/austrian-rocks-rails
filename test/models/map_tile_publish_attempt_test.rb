# frozen_string_literal: true

require "test_helper"

class MapTilePublishAttemptTest < ActiveSupport::TestCase
  test "has valid sources" do
    assert_includes MapTilePublishAttempt::SOURCES, "manual"
    assert_includes MapTilePublishAttempt::SOURCES, "automatic"
  end

  test "has valid statuses" do
    assert_includes MapTilePublishAttempt::STATUSES, "pending"
    assert_includes MapTilePublishAttempt::STATUSES, "running"
    assert_includes MapTilePublishAttempt::STATUSES, "succeeded"
    assert_includes MapTilePublishAttempt::STATUSES, "failed"
    assert_includes MapTilePublishAttempt::STATUSES, "cancelled"
  end

  test "validates source inclusion" do
    attempt = MapTilePublishAttempt.new(source: "invalid", status: "pending")
    assert_not attempt.valid?
    assert_includes attempt.errors[:source], "is not included in the list"
  end

  test "validates status inclusion" do
    attempt = MapTilePublishAttempt.new(source: "manual", status: "invalid")
    assert_not attempt.valid?
    assert_includes attempt.errors[:status], "is not included in the list"
  end

  test "requires source" do
    attempt = MapTilePublishAttempt.new(status: "pending")
    assert_not attempt.valid?
    assert_includes attempt.errors[:source], "can't be blank"
  end

  test "requires status" do
    attempt = MapTilePublishAttempt.new(source: "manual", status: nil)
    assert_not attempt.valid?
    assert attempt.errors[:status].any?
  end

  test "valid manual pending attempt" do
    attempt = MapTilePublishAttempt.new(source: "manual", status: "pending")
    assert attempt.valid?
  end

  test "returns duration from started_at and finished_at" do
    attempt = MapTilePublishAttempt.new(
      source: "manual",
      status: "succeeded",
      started_at: 10.seconds.ago,
      finished_at: Time.current
    )
    assert_in_delta 10.0, attempt.duration, 0.1
  end

  test "returns nil duration without started_at" do
    attempt = MapTilePublishAttempt.new(
      source: "manual",
      status: "pending",
      finished_at: Time.current
    )
    assert_nil attempt.duration
  end

  test "returns nil duration without finished_at" do
    attempt = MapTilePublishAttempt.new(
      source: "manual",
      status: "running",
      started_at: Time.current
    )
    assert_nil attempt.duration
  end

  test "record_failure! sets failed status and sanitized error text" do
    attempt = MapTilePublishAttempt.create!(source: "manual", status: "running")
    error = RuntimeError.new("Something went wrong with BUNNY_STORAGE_ACCESS_KEY_ID=secret123")

    attempt.record_failure!(error)

    assert_equal "failed", attempt.reload.status
    assert_includes attempt.error_text, "[REDACTED BUNNY_STORAGE_ACCESS_KEY_ID]"
    assert_not_includes attempt.error_text, "secret123"
  end

  test "record_failure! redacts multiple Bunny credential keys" do
    attempt = MapTilePublishAttempt.create!(source: "automatic", status: "running")
    error = RuntimeError.new(
      "Access denied: BUNNY_STORAGE_ACCESS_KEY_ID=abc BUNNY_STORAGE_SECRET_ACCESS_KEY=def"
    )

    attempt.record_failure!(error)

    assert_includes attempt.error_text, "[REDACTED BUNNY_STORAGE_ACCESS_KEY_ID]"
    assert_includes attempt.error_text, "[REDACTED BUNNY_STORAGE_SECRET_ACCESS_KEY]"
    assert_not_includes attempt.error_text, "abc"
    assert_not_includes attempt.error_text, "def"
  end

  test "record_failure! truncates error text to 2000 characters" do
    attempt = MapTilePublishAttempt.create!(source: "manual", status: "running")
    long_error = RuntimeError.new("x" * 5000)

    attempt.record_failure!(long_error)

    assert attempt.error_text.length <= 2000
  end

  test "record_failure! sets finished_at" do
    freeze_time do
      attempt = MapTilePublishAttempt.create!(source: "manual", status: "running")
      error = RuntimeError.new("fail")

      attempt.record_failure!(error)

      assert_equal Time.current, attempt.reload.finished_at
    end
  end

  test "handles non-message error objects for record_failure!" do
    attempt = MapTilePublishAttempt.create!(source: "manual", status: "running")

    attempt.record_failure!("raw string error")

    assert_equal "failed", attempt.reload.status
    assert_includes attempt.error_text, "raw string error"
  end
end
