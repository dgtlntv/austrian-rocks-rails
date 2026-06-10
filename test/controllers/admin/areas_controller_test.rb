require "test_helper"

class Admin::AreasControllerTest < ActionDispatch::IntegrationTest
  test "update persists guidebook and parking poi" do
    area = Area.create!(name: "Card Area", slug: "card-area")
    guidebook = Guidebook.create!(title: "Area Guide", url: "https://example.com/area")
    parking = Poi.create!(name: "Area Parking", poi_type: "parking")

    patch admin_area_path(area, locale: :en), params: {
      area: {
        name: area.name,
        joined_tags: "",
        guidebook_id: guidebook.id,
        parking_poi_id: parking.id
      }
    }

    assert_redirected_to edit_admin_area_path(area, locale: :en)
    area.reload
    assert_equal guidebook, area.guidebook
    assert_equal parking, area.parking_poi
  end
end
