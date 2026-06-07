require "test_helper"

class PoiTest < ActiveSupport::TestCase
  test "has many areas through poi routes" do
    area = Area.create!(name: "POI Association Area", slug: "poi-association-area")
    poi = Poi.create!(name: "Parking", poi_type: "parking")
    PoiRoute.create!(area: area, poi: poi, distance: 100, transport: "walking")

    assert_equal [ area ], poi.areas
  end
end
