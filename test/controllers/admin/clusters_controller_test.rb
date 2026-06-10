require "test_helper"

class Admin::ClustersControllerTest < ActionDispatch::IntegrationTest
  test "update persists warnings, guidebook, and parking poi" do
    cluster = Cluster.create!(name: "Card Cluster", slug: "card-cluster")
    guidebook = Guidebook.create!(title: "Cluster Guide", url: "https://example.com/cluster")
    parking = Poi.create!(name: "Cluster Parking", poi_type: "parking")

    patch admin_cluster_path(cluster, locale: :en), params: {
      cluster: {
        name: cluster.name,
        warning_de: "Achtung",
        warning_en: "Warning",
        guidebook_id: guidebook.id,
        parking_poi_id: parking.id
      }
    }

    assert_redirected_to edit_admin_cluster_path(cluster, locale: :en)
    cluster.reload
    assert_equal "Achtung", cluster.warning_de
    assert_equal "Warning", cluster.warning_en
    assert_equal guidebook, cluster.guidebook
    assert_equal parking, cluster.parking_poi
  end
end
