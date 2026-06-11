require "test_helper"

class Admin::RegionsControllerTest < ActionDispatch::IntegrationTest
  test "update persists warnings, guidebook, and parking poi" do
    region = Region.create!(name: "Card Region", slug: "card-region")
    guidebook = Guidebook.create!(title: "Region Guide", url: "https://example.com/region")
    parking = Poi.create!(name: "Region Parking", poi_type: "parking")

    patch admin_region_path(region, locale: :en), params: {
      region: {
        name: region.name,
        warning_de: "Achtung",
        warning_en: "Warning",
        guidebook_id: guidebook.id,
        parking_poi_id: parking.id
      }
    }

    assert_redirected_to edit_admin_region_path(region, locale: :en)
    region.reload
    assert_equal "Achtung", region.warning_de
    assert_equal "Warning", region.warning_en
    assert_equal guidebook, region.guidebook
    assert_equal parking, region.parking_poi
  end
end
