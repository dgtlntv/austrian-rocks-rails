# frozen_string_literal: true

require "fileutils"
require "map_tiles/configuration"

module MapTiles
  class LocalArtifactCleaner
    DEFAULT_RETENTION_DAYS = 14
    SECONDS_PER_DAY = 86_400

    attr_reader :configuration, :retention_days, :now, :out

    def initialize(configuration: Configuration.new, retention_days: DEFAULT_RETENTION_DAYS, now: Time.current, out: $stdout)
      @configuration = configuration
      @retention_days = Integer(retention_days)
      @now = now
      @out = out
    end

    def clean
      return [] unless configuration.output_dir.exist?

      removed_paths = cleanup_candidates.select { |path| expired?(path) && !current_artifact?(path) }
      removed_paths.each { |path| FileUtils.rm_f(path) }
      out.puts "cleaned #{removed_paths.length} old local map release artifact(s) older than #{retention_days} day(s)"
      removed_paths
    end

    private

    def cleanup_candidates
      patterns.flat_map { |pattern| Dir.glob(pattern) }.map { |path| Pathname(path) }.select(&:file?)
    end

    def patterns
      basename = configuration.artifact_basename
      [
        configuration.output_dir.join("#{basename}-*.pmtiles").to_s,
        configuration.output_dir.join("#{basename}-*.metadata.json").to_s,
        configuration.output_dir.join("#{basename}-*-light.json").to_s,
        configuration.output_dir.join("#{basename}-*-dark.json").to_s,
        configuration.output_dir.join(configuration.manifest_object_name).to_s
      ]
    end

    def expired?(path)
      path.mtime < now - (retention_days * SECONDS_PER_DAY)
    end

    def current_artifact?(path)
      [
        configuration.artifact_path,
        configuration.metadata_path,
        configuration.style_artifact_path("light"),
        configuration.style_artifact_path("dark"),
        configuration.manifest_artifact_path
      ].map(&:to_s).include?(path.to_s)
    end
  end
end
