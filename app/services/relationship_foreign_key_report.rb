class RelationshipForeignKeyReport
  CANDIDATES = [
    { table: "areas", column: "cluster_id", target_table: "clusters" },
    { table: "clusters", column: "region_id", target_table: "regions" },
    { table: "lines", column: "problem_id", target_table: "problems" },
    { table: "lines", column: "topo_id", target_table: "topos" },
    { table: "poi_routes", column: "area_id", target_table: "areas" },
    { table: "poi_routes", column: "poi_id", target_table: "pois" },
    { table: "contribution_requests", column: "problem_id", target_table: "problems" },
    { table: "contributions", column: "problem_id", target_table: "problems" },
    { table: "problems", column: "parent_id", target_table: "problems" },
    { table: "clusters", column: "main_area_id", target_table: "areas" },
    { table: "regions", column: "main_cluster_id", target_table: "clusters" },
    { table: "topos", column: "boulder_id", target_table: "boulders" }
  ].freeze

  class << self
    def report(candidates: CANDIDATES)
      candidates.map { |candidate| report_candidate(candidate) }
    end

    private

    def report_candidate(candidate)
      row_ids = dirty_row_ids(candidate)

      candidate.merge(
        count: row_ids.length,
        row_ids: row_ids,
        status: row_ids.empty? ? "clean" : "deferred"
      )
    end

    def dirty_row_ids(candidate)
      connection = ActiveRecord::Base.connection
      source_table = connection.quote_table_name(candidate[:table])
      target_table = connection.quote_table_name(candidate[:target_table])
      source_column = connection.quote_column_name(candidate[:column])

      connection.select_values(<<~SQL.squish)
        SELECT source.id
        FROM #{source_table} source
        LEFT JOIN #{target_table} target ON target.id = source.#{source_column}
        WHERE source.#{source_column} IS NOT NULL
          AND target.id IS NULL
        ORDER BY source.id
      SQL
    end
  end
end
