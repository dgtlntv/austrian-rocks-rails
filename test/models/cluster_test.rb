require "test_helper"

class ClusterTest < ActiveSupport::TestCase
  test "guidebook and parking poi round-trip" do
    guidebook = Guidebook.create!(title: "Cluster Guide", url: "https://example.com/cluster")
    parking = Poi.create!(name: "Cluster Parking", poi_type: "parking")
    cluster = Cluster.create!(name: "Assoc Cluster", slug: "assoc-cluster", guidebook: guidebook, parking_poi: parking)

    cluster.reload
    assert_equal guidebook, cluster.guidebook
    assert_equal parking, cluster.parking_poi
  end

  test "parking poi must be a parking poi" do
    station = Poi.create!(name: "Cluster Station", poi_type: "train_station")
    cluster = Cluster.new(name: "Station Cluster", parking_poi: station)

    assert_not cluster.valid?
    assert_includes cluster.errors[:parking_poi], "must be a parking POI"
  end

  test "normalizes blank warnings to nil" do
    cluster = Cluster.create!(name: "Warning Cluster", slug: "warning-cluster", warning_de: "  Achtung  ", warning_en: "   ")

    assert_equal "Achtung", cluster.warning_de
    assert_nil cluster.warning_en
  end
end
