require "test_helper"

class BoulderTest < ActiveSupport::TestCase
  test "has many problems and topos" do
    area = Area.create!(name: "Boulder Association Area", slug: "boulder-association-area")
    boulder = Boulder.create!(area: area)
    problem = Problem.create!(area: area, boulder: boulder, steepness: "wall")
    topo = Topo.new(boulder: boulder)
    topo.save!(validate: false)

    assert_includes boulder.problems, problem
    assert_includes boulder.topos, topo
  end
end
