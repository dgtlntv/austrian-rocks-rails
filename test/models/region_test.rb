require "test_helper"

class RegionTest < ActiveSupport::TestCase
  test "guidebook and parking poi round-trip" do
    guidebook = Guidebook.create!(title: "Region Guide", url: "https://example.com/region")
    parking = Poi.create!(name: "Region Parking", poi_type: "parking")
    region = Region.create!(name: "Assoc Region", slug: "assoc-region", guidebook: guidebook, parking_poi: parking)

    region.reload
    assert_equal guidebook, region.guidebook
    assert_equal parking, region.parking_poi
  end

  test "parking poi must be a parking poi" do
    station = Poi.create!(name: "Region Station", poi_type: "train_station")
    region = Region.new(name: "Station Region", parking_poi: station)

    assert_not region.valid?
    assert_includes region.errors[:parking_poi], "must be a parking POI"
  end

  test "normalizes blank warnings to nil" do
    region = Region.create!(name: "Warning Region", slug: "warning-region", warning_de: "  Achtung  ", warning_en: "   ")

    assert_equal "Achtung", region.warning_de
    assert_nil region.warning_en
  end
end
