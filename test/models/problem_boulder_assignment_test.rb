require "test_helper"

class ProblemBoulderAssignmentTest < ActiveSupport::TestCase
  setup do
    @area = Area.create!(name: "Assignment Area", slug: "assignment-area")
    @other_area = Area.create!(name: "Other Assignment Area", slug: "other-assignment-area")
  end

  test "reports matched missing no-containing multiple-containing and area-mismatch cases" do
    matched_boulder = create_boulder(@area, [[ 0, 0 ], [ 2, 0 ], [ 2, 2 ], [ 0, 2 ], [ 0, 0 ]])
    create_boulder(@area, [[ 10, 10 ], [ 12, 10 ], [ 12, 12 ], [ 10, 12 ], [ 10, 10 ]])
    create_boulder(@area, [[ 20, 20 ], [ 22, 20 ], [ 22, 22 ], [ 20, 22 ], [ 20, 20 ]])
    create_boulder(@area, [[ 21, 21 ], [ 23, 21 ], [ 23, 23 ], [ 21, 23 ], [ 21, 21 ]])
    mismatched_boulder = create_boulder(@other_area, [[ 30, 30 ], [ 32, 30 ], [ 32, 32 ], [ 30, 32 ], [ 30, 30 ]])

    matched = create_problem(@area, location: point(1, 1))
    missing_location = create_problem(@area, location: nil)
    no_containing_boulder = create_problem(@area, location: point(50, 50))
    multiple_containing_boulders = create_problem(@area, location: point(21.5, 21.5))
    area_mismatch = create_problem(@area, location: point(31, 31), boulder: mismatched_boulder)

    report = ProblemBoulderAssignment.report(Problem.where(id: [
      matched.id,
      missing_location.id,
      no_containing_boulder.id,
      multiple_containing_boulders.id,
      area_mismatch.id
    ]))

    assert_equal [ matched.id ], report[:categories][:matched]
    assert_equal matched_boulder.id, report[:assignments][matched.id]
    assert_equal [ missing_location.id ], report[:categories][:missing_location]
    assert_equal [ no_containing_boulder.id ], report[:categories][:no_containing_boulder]
    assert_equal [ multiple_containing_boulders.id ], report[:categories][:multiple_containing_boulders]
    assert_equal [ area_mismatch.id ], report[:categories][:area_mismatch]
  end

  test "backfill assigns only unambiguous matches" do
    boulder = create_boulder(@area, [[ 0, 0 ], [ 2, 0 ], [ 2, 2 ], [ 0, 2 ], [ 0, 0 ]])
    matched = create_problem(@area, location: point(1, 1))
    unmatched = create_problem(@area, location: point(50, 50))

    result = ProblemBoulderAssignment.backfill(Problem.where(id: [ matched.id, unmatched.id ]))

    assert_equal [ matched.id ], result[:updated_ids]
    assert_equal boulder, matched.reload.boulder
    assert_nil unmatched.reload.boulder
  end

  private

  def create_boulder(area, coordinates)
    Boulder.create!(area: area, polygon: polygon(coordinates))
  end

  def create_problem(area, location:, boulder: nil)
    Problem.create!(area: area, location: location, boulder: boulder, steepness: "wall")
  end

  def point(lon, lat)
    FACTORY.point(lon, lat)
  end

  def polygon(coordinates)
    FACTORY.polygon(FACTORY.line_string(coordinates.map { |lon, lat| point(lon, lat) }))
  end
end
