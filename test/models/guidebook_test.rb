require "test_helper"

class GuidebookTest < ActiveSupport::TestCase
  test "requires title and url" do
    guidebook = Guidebook.new

    assert_not guidebook.valid?
    assert_includes guidebook.errors[:title], "can't be blank"
    assert_includes guidebook.errors[:url], "can't be blank"
  end

  test "accepts http and https urls" do
    assert Guidebook.new(title: "Bloc", url: "http://example.com/bloc").valid?
    assert Guidebook.new(title: "Bloc", url: "https://example.com/bloc").valid?
  end

  test "rejects javascript and bare-word urls" do
    assert_not Guidebook.new(title: "Bad", url: "javascript:alert(1)").valid?
    assert_not Guidebook.new(title: "Bad", url: "example.com/bloc").valid?
  end

  test "normalizes blank author and strips fields" do
    guidebook = Guidebook.create!(title: "  Bloc  ", author: "   ", url: "  https://example.com/bloc  ")

    assert_equal "Bloc", guidebook.title
    assert_nil guidebook.author
    assert_equal "https://example.com/bloc", guidebook.url
  end

  test "is associated from regions, clusters, and areas" do
    guidebook = Guidebook.create!(title: "Bloc", url: "https://example.com/bloc")
    region = Region.create!(name: "Guidebook Region", slug: "guidebook-region", guidebook: guidebook)
    cluster = Cluster.create!(name: "Guidebook Cluster", slug: "guidebook-cluster", guidebook: guidebook)
    area = Area.create!(name: "Guidebook Area", slug: "guidebook-area", guidebook: guidebook)

    assert_equal [ region ], guidebook.regions
    assert_equal [ cluster ], guidebook.clusters
    assert_equal [ area ], guidebook.areas
  end
end
