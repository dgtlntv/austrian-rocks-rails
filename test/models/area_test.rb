require "test_helper"

class AreaTest < ActiveSupport::TestCase
  test "guidebook and parking poi round-trip" do
    guidebook = Guidebook.create!(title: "Area Guide", url: "https://example.com/area")
    parking = Poi.create!(name: "Area Parking", poi_type: "parking")
    area = Area.create!(name: "Assoc Area", slug: "assoc-area", guidebook: guidebook, parking_poi: parking)

    area.reload
    assert_equal guidebook, area.guidebook
    assert_equal parking, area.parking_poi
  end

  test "parking poi must be a parking poi" do
    station = Poi.create!(name: "Area Station", poi_type: "train_station")
    area = Area.new(name: "Station Area", slug: "station-area", parking_poi: station)

    assert_not area.valid?
    assert_includes area.errors[:parking_poi], "must be a parking POI"
  end
end
