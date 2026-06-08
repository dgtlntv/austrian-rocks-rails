# frozen_string_literal: true

# Persisted record for each PMTiles publish attempt (manual or automatic).
# Tracks the full lifecycle: pending → running → succeeded / failed / cancelled.
# Sanitizes error text to avoid leaking Bunny credentials or provider response bodies.
class MapTilePublishAttempt < ApplicationRecord
  SOURCES = %w[manual automatic].freeze
  STATUSES = %w[pending running succeeded failed cancelled].freeze

  validates :source, inclusion: { in: SOURCES }
  validates :status, inclusion: { in: STATUSES }
  validates :source, presence: true
  validates :status, presence: true

  scope :recent, -> { order(created_at: :desc) }

  # Returns duration in seconds when both started_at and finished_at exist.
  def duration
    return nil unless started_at && finished_at

    finished_at - started_at
  end

  # Records a failure outcome, sanitising error text to remove credential leaks.
  def record_failure!(error, finished_at: Time.current)
    sanitized = sanitize_error_text(error)
    update!(status: "failed", error_text: sanitized, finished_at: finished_at)
  end

  private

  BUNNY_SECRET_KEYS = %w[
    BUNNY_STORAGE_ACCESS_KEY_ID
    BUNNY_STORAGE_SECRET_ACCESS_KEY
    BUNNY_CDN_API_KEY
    BUNNY_API_KEY
  ].freeze

  def sanitize_error_text(error)
    text = error.respond_to?(:message) ? error.message : error.to_s
    return "" if text.blank?

    BUNNY_SECRET_KEYS.each do |key|
      text = text.gsub(/#{Regexp.escape(key)}=[^\s]*/i, "[REDACTED #{key}]")
    end
    text.truncate(2000)
  end
end
