# frozen_string_literal: true

# Singleton model representing the current PMTiles publish workflow state.
# Exactly one row exists at any time (created on first access via self.current!).
# Derives the human-readable status from its own fields and associated attempts:
#
#   running  →  running_attempt_id is set and the attempt is in status "running"
#   pending  →  a pending automatic publish attempt is scheduled
#   failed   →  the most recent attempt failed and no publish is running/pending
#   stale    →  source data changed since the last successful publish
#   up_to_date  →  otherwise
#
# Concurrency protection is provided by locking this row before any job
# transitions a publish attempt to running.
class MapTilePublishState < ApplicationRecord
  belongs_to :pending_automatic_attempt, class_name: "MapTilePublishAttempt", optional: true
  belongs_to :running_attempt, class_name: "MapTilePublishAttempt", optional: true
  belongs_to :last_successful_attempt, class_name: "MapTilePublishAttempt", optional: true
  belongs_to :last_failed_attempt, class_name: "MapTilePublishAttempt", optional: true

  # Returns or creates the singleton publish state row.
  def self.current!
    first_or_create!
  end

  # Derives the current published-status label for admin UI rendering.
  def current_status
    if running_attempt_id.present? && running_attempt&.status == "running"
      "running"
    elsif pending_automatic_attempt_id.present?
      "pending"
    elsif last_failed_attempt_id.present? && (last_successful_attempt_id.nil? || (stale_at.present? && stale_at > (last_successful_attempt&.finished_at || Time.at(0))))
      "failed"
    elsif stale_at.present? && (last_successful_attempt_id.nil? || stale_at > (last_successful_attempt&.finished_at || Time.at(0)))
      "stale"
    else
      "up_to_date"
    end
  end
end
