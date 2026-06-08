# frozen_string_literal: true

module MapTiles
  # Coordinates manual and automatic PMTiles publish scheduling.
  #
  # Manual publishes create a single pending attempt and enqueue one
  # immediate job. Automatic scheduling maintains the sliding debounce
  # invariant: many source-model edits collapse into exactly one pending
  # automatic attempt, and each edit slides the scheduled time forward.
  # Edits that arrive while a publish is running request a follow-up
  # attempt rather than starting a second concurrent build — concurrency
  # protection is enforced in MapTilePublishJob.
  class PublishScheduler
    def initialize(configuration: nil, publish_job_class: nil)
      @configuration = configuration || MapTiles::Configuration.new
      @publish_job_class = publish_job_class
    end

    # Creates a manual publish attempt and enqueues an immediate job.
    def enqueue_manual!(reason:, at: Time.current)
      attempt = MapTilePublishAttempt.create!(
        source: "manual",
        status: "pending",
        trigger_reason: reason,
        scheduled_for: at,
        enqueued_at: at
      )
      publish_job_class.perform_later(attempt.id)
      attempt
    end

    # Marks PMTiles data as stale and maintains one sliding-debounced
    # pending automatic publish attempt.
    #
    # Sliding debounce invariant:
    #   Many source-model edits (create/update/destroy on any PMTiles
    #   source model) collapse into a single pending automatic attempt.
    #   Each call moves the pending attempt's scheduled_for forward to
    #   `now + debounce_delay`, so rapid editing batches into one build.
    #   Edits during a running publish do not create a concurrent build;
    #   they instead ensure a follow-up pending automatic attempt exists
    #   for after the current run finishes.
    #
    # Locking: acquires a database row lock on the singleton state row
    # so concurrent stale-marking calls serialise correctly.
    def mark_stale!(reason:, at: Time.current)
      state = MapTilePublishState.current!

      state.with_lock do
        state.update!(stale_at: at, last_source_change_at: at)

        scheduled_for = at + configuration.automatic_publish_debounce

        if state.pending_automatic_attempt_id.present?
          attempt = state.pending_automatic_attempt
          attempt.update!(
            trigger_reason: reason,
            scheduled_for: scheduled_for
          )
        else
          attempt = MapTilePublishAttempt.create!(
            source: "automatic",
            status: "pending",
            trigger_reason: reason,
            scheduled_for: scheduled_for,
            enqueued_at: at
          )
          state.update!(pending_automatic_attempt: attempt)
        end

        # Enqueue (or re-enqueue) the job at the new scheduled_for.
        # Previously enqueued jobs that wake up before this time will
        # self-reschedule in MapTilePublishJob.
        publish_job_class
          .set(wait_until: scheduled_for)
          .perform_later(attempt.id)
      end
    end

    private

    def publish_job_class
      @publish_job_class || resolve_job_class
    end

    def resolve_job_class
      Object.const_defined?(:MapTilePublishJob) ? ::MapTilePublishJob : nil
    end

    attr_reader :configuration
  end
end
