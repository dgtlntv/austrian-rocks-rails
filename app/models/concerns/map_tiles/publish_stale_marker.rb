# frozen_string_literal: true

module MapTiles
  # Concern that marks PMTiles data stale after source-model commits.
  #
  # Include this in any model whose create/update/destroy commits should
  # schedule an automatic PMTiles publish. The callback is a no-op
  # outside of Rails.env.production? so development and test saves
  # never inadvertently schedule publishes through normal CRUD.
  #
  # Tests that need to exercise scheduling should call
  # MapTiles::PublishScheduler directly.
  module PublishStaleMarker
    extend ActiveSupport::Concern

    included do
      after_commit :mark_map_tiles_stale_for_publish, on: %i[create update destroy]
    end

    private

    def mark_map_tiles_stale_for_publish
      return unless Rails.env.production?

      MapTiles::PublishScheduler.new.mark_stale!(
        reason: "#{self.class.name}##{id} changed"
      )
    end
  end
end
