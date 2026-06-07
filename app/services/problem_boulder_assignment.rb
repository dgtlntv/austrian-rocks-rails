class ProblemBoulderAssignment
  MATCH_TOLERANCE_DEGREES = BigDecimal("1e-06")
  CATEGORIES = %i[
    matched
    missing_location
    no_containing_boulder
    multiple_containing_boulders
    area_mismatch
  ].freeze

  class << self
    def report(scope = Problem.all)
      result = empty_report

      scope.includes(:boulder).find_each do |problem|
        category, boulder_ids = classify(problem)
        result[:categories][category] << problem.id
        result[:assignments][problem.id] = boulder_ids.first if category == :matched
      end

      result
    end

    def backfill(scope = Problem.all, report_result = report(scope))
      updated_ids = []

      Problem.transaction do
        report_result[:assignments].each do |problem_id, boulder_id|
          updated_ids << problem_id if scope.where(id: problem_id).update_all(boulder_id: boulder_id).positive?
        end
      end

      report_result.merge(updated_ids: updated_ids)
    end

    private

    def empty_report
      {
        categories: CATEGORIES.index_with { [] },
        assignments: {},
        updated_ids: []
      }
    end

    def classify(problem)
      return [ :area_mismatch, [ problem.boulder_id ] ] if area_mismatch?(problem)
      return [ :missing_location, [] ] if problem.location.blank?

      boulder_ids = containing_boulder_ids(problem)

      case boulder_ids.length
      when 0
        [ :no_containing_boulder, [] ]
      when 1
        [ :matched, boulder_ids ]
      else
        [ :multiple_containing_boulders, boulder_ids ]
      end
    end

    def area_mismatch?(problem)
      problem.boulder_id.present? && problem.boulder&.area_id != problem.area_id
    end

    # Assignment is intentionally conservative: exactly one boulder in the problem's own area
    # must spatially cover, or be within the tiny legacy near-boundary tolerance of, the point.
    # Ambiguous and unmatched rows stay unset so maintainers can inspect them explicitly.
    def containing_boulder_ids(problem)
      ewkt = "SRID=4326;#{problem.location.as_text}"

      Boulder.where(area_id: problem.area_id).where.not(polygon: nil).
        where(
          "ST_Covers(boulders.polygon::geometry, ST_GeomFromEWKT(?)) OR " \
            "ST_DWithin(boulders.polygon::geometry, ST_GeomFromEWKT(?), ?)",
          ewkt,
          ewkt,
          MATCH_TOLERANCE_DEGREES
        ).order(:id).pluck(:id)
    end
  end
end
