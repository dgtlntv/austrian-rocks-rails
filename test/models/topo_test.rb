require "test_helper"

class TopoTest < ActiveSupport::TestCase
  test "optionally belongs to boulder" do
    area = Area.create!(name: "Topo Association Area", slug: "topo-association-area")
    boulder = Boulder.create!(area: area)
    topo = Topo.new(boulder: boulder)

    assert_equal boulder, topo.boulder
  end
end
