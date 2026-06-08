# frozen_string_literal: true

require "map_tiles/geojson_exporter"
require "map_tiles/tippecanoe_builder"
require "map_tiles/smoke_check"
require "map_tiles/bunny_publisher"
require "map_tiles/local_artifact_cleaner"

module MapTiles
  # Orchestrates the PMTiles publication pipeline for a claimed attempt.
  # Expensive work happens here, outside the job's state lock: export source
  # GeoJSON, build PMTiles, run the production smoke check, publish, clean up,
  # then persist durable success/failure history.
  class PublishPipeline
    attr_reader :configuration, :exporter_class, :builder_class, :smoke_check_class,
      :publisher_class, :cleaner_class, :clock, :publish_job_class

    def initialize(
      configuration: Configuration.new,
      exporter_class: GeojsonExporter,
      builder_class: TippecanoeBuilder,
      smoke_check_class: SmokeCheck,
      publisher_class: BunnyPublisher,
      cleaner_class: LocalArtifactCleaner,
      clock: -> { Time.current },
      publish_job_class: MapTilePublishJob
    )
      @configuration = configuration
      @exporter_class = exporter_class
      @builder_class = builder_class
      @smoke_check_class = smoke_check_class
      @publisher_class = publisher_class
      @cleaner_class = cleaner_class
      @clock = clock
      @publish_job_class = publish_job_class
    end

    def call(attempt)
      version = timestamp_version
      versioned_configuration = configuration.with_version(version)
      attempt.update!(version: version)

      layer_paths = exporter_class.new(configuration: versioned_configuration).export
      builder_class.new(configuration: versioned_configuration).build(layer_paths: layer_paths)
      smoke_check_class.new(configuration: versioned_configuration, argv: [ "--mode=production" ]).run
      published = publisher_class.new(configuration: versioned_configuration).publish
      cleaner_class.new(configuration: versioned_configuration).clean

      record_success!(attempt, published: published, configuration: versioned_configuration, finished_at: clock.call)
    rescue StandardError => e
      record_failure!(attempt, e, finished_at: clock.call)
    end

    private

    def timestamp_version
      clock.call.utc.strftime("%Y-%m-%dT%H-%M-%SZ")
    end

    def record_success!(attempt, published:, configuration:, finished_at:)
      published_objects = published_objects_from(published, configuration: configuration)

      attempt.update!(
        status: "succeeded",
        finished_at: finished_at,
        pmtiles_url: published_objects.fetch(:pmtiles).fetch(:url),
        manifest_url: published_objects.fetch(:manifest).fetch(:url),
        pmtiles_object_key: published_objects.fetch(:pmtiles).fetch(:key),
        manifest_object_key: published_objects.fetch(:manifest).fetch(:key),
        error_text: nil
      )

      follow_up_attempt = nil
      state = MapTilePublishState.current!
      state.with_lock do
        state.reload
        state.running_attempt = nil if state.running_attempt_id == attempt.id
        state.last_successful_attempt = attempt

        if stale_change_after?(state, attempt)
          follow_up_attempt = ensure_pending_follow_up!(state)
        else
          state.stale_at = nil
          supersede_pending_automatic!(state, attempt: attempt, finished_at: finished_at)
        end

        state.save!
      end

      enqueue_follow_up(follow_up_attempt) if follow_up_attempt&.previously_new_record?
    end

    def record_failure!(attempt, error, finished_at:)
      attempt.record_failure!(error, finished_at: finished_at)

      state = MapTilePublishState.current!
      state.with_lock do
        state.reload
        state.running_attempt = nil if state.running_attempt_id == attempt.id
        state.last_failed_attempt = attempt
        state.save!
      end
    end

    def stale_change_after?(state, attempt)
      state.stale_at.present? && attempt.started_at.present? && state.stale_at > attempt.started_at
    end

    def ensure_pending_follow_up!(state)
      existing = state.pending_automatic_attempt
      return existing if existing&.status == "pending"

      scheduled_for = state.stale_at + configuration.automatic_publish_debounce
      attempt = MapTilePublishAttempt.create!(
        source: "automatic",
        status: "pending",
        trigger_reason: "PMTiles source data changed during publish",
        scheduled_for: scheduled_for,
        enqueued_at: clock.call
      )
      state.pending_automatic_attempt = attempt
      attempt
    end

    def supersede_pending_automatic!(state, attempt:, finished_at:)
      pending_attempt = state.pending_automatic_attempt
      return if pending_attempt.blank? || pending_attempt.id == attempt.id

      if pending_attempt.status == "pending"
        pending_attempt.update!(
          status: "cancelled",
          finished_at: finished_at,
          error_text: "Superseded by successful PMTiles publish"
        )
      end

      state.pending_automatic_attempt = nil
    end

    def enqueue_follow_up(attempt)
      publish_job_class.set(wait_until: attempt.scheduled_for).perform_later(attempt.id)
    end

    def published_objects_from(published, configuration:)
      if published.is_a?(Hash) && (published.key?(:pmtiles) || published.key?("pmtiles"))
        pmtiles = object_hash(published[:pmtiles] || published["pmtiles"])
        manifest = object_hash(published[:manifest] || published["manifest"] || {})
      else
        objects = Array(published).map { |object| object_hash(object) }
        pmtiles = objects.find { |object| object[:key] == configuration.versioned_object_key } || objects.first || {}
        manifest = objects.find { |object| object[:key] == configuration.latest_manifest_object_key } ||
          objects.find { |object| object[:key].to_s.include?("latest") } || objects.second || {}
      end

      {
        pmtiles: {
          key: pmtiles[:key].presence || configuration.versioned_object_key,
          url: pmtiles[:url].presence || public_url_for(configuration.versioned_object_key, configuration: configuration)
        },
        manifest: {
          key: manifest[:key].presence || configuration.latest_manifest_object_key,
          url: manifest[:url].presence || public_url_for(configuration.latest_manifest_object_key, configuration: configuration)
        }
      }
    end

    def object_hash(object)
      object.to_h.transform_keys(&:to_sym)
    end

    def public_url_for(key, configuration:)
      host = configuration.public_cdn_host.to_s.delete_suffix("/")
      host = "https://#{host}" unless host.match?(%r{\Ahttps?://}i)
      "#{host}/#{key}"
    end
  end
end
