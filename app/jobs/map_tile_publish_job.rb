# frozen_string_literal: true

# Background entry point for PMTiles publish attempts.
# Claims one pending attempt under the singleton publish-state lock before
# running the expensive build/publish pipeline outside the lock.
class MapTilePublishJob < ApplicationJob
  queue_as :default

  def perform(attempt_id)
    attempt = MapTilePublishAttempt.find_by(id: attempt_id)
    return if attempt.blank?

    return unless claim_attempt(attempt, at: Time.current)

    MapTiles::PublishPipeline.new.call(attempt)
  end

  private

  def claim_attempt(attempt, at:)
    state = MapTilePublishState.current!

    state.with_lock do
      attempt.reload
      return false unless attempt.status == "pending"

      if early_automatic_attempt?(attempt, at: at)
        self.class.set(wait_until: attempt.scheduled_for).perform_later(attempt.id)
        return false
      end

      if publish_running?(state)
        handle_already_running!(attempt, at: at)
        return false
      end

      attempt.update!(status: "running", started_at: at, error_text: nil)

      state.pending_automatic_attempt = nil if state.pending_automatic_attempt_id == attempt.id
      state.running_attempt = attempt
      state.save!

      true
    end
  end

  def early_automatic_attempt?(attempt, at:)
    attempt.source == "automatic" && attempt.scheduled_for.present? && attempt.scheduled_for > at
  end

  def publish_running?(state)
    state.running_attempt_id.present? && state.running_attempt&.status == "running"
  end

  def handle_already_running!(attempt, at:)
    if attempt.source == "automatic"
      next_run_at = [ attempt.scheduled_for, at + configuration.automatic_publish_debounce ].compact.max
      attempt.update!(scheduled_for: next_run_at, enqueued_at: at)
      self.class.set(wait_until: next_run_at).perform_later(attempt.id)
    else
      attempt.update!(
        status: "cancelled",
        error_text: "Another PMTiles publish is already running",
        finished_at: at
      )
    end
  end

  def configuration
    @configuration ||= MapTiles::Configuration.new
  end
end
