class Admin::ExportsController < Admin::BaseController
  def index
    load_map_tile_publish_state
  end

  def db
    tempfile = Tempfile.new([ BRAND_CONFIG[:slug], ".db" ])
    AppDbExporter.call(tempfile.path)

    send_file tempfile.path,
      filename: "#{BRAND_CONFIG[:slug]}.db",
      type: "application/x-sqlite3",
      disposition: :attachment
  ensure
    tempfile&.close
  end

  def publish_pmtiles
    MapTiles::PublishScheduler.new.enqueue_manual!(reason: "Manual admin publish")

    redirect_to admin_exports_path, notice: "PMTiles publish queued."
  end

  private

  def load_map_tile_publish_state
    @map_tile_state = MapTilePublishState.current!
    @last_successful_attempt = @map_tile_state.last_successful_attempt
    @pending_automatic_attempt = @map_tile_state.pending_automatic_attempt
    @recent_map_tile_attempts = MapTilePublishAttempt.order(created_at: :desc).limit(25)
  end
end
