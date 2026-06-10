require "test_helper"

class Admin::GuidebooksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @guidebook = Guidebook.create!(title: "Existing Guide", author: "Author", url: "https://example.com/existing")
  end

  test "index lists guidebooks" do
    get admin_guidebooks_path(locale: :en)

    assert_response :success
    assert_includes response.body, @guidebook.title
  end

  test "new renders form" do
    get new_admin_guidebook_path(locale: :en)

    assert_response :success
    assert_includes response.body, "New guidebook"
  end

  test "create guidebook" do
    assert_difference "Guidebook.count", 1 do
      post admin_guidebooks_path(locale: :en), params: {
        guidebook: { title: "New Guide", author: "Someone", url: "https://example.com/new" }
      }
    end

    guidebook = Guidebook.order(:id).last
    assert_redirected_to edit_admin_guidebook_path(guidebook, locale: :en)
    assert_equal "New Guide", guidebook.title
  end

  test "create with invalid url rerenders form" do
    assert_no_difference "Guidebook.count" do
      post admin_guidebooks_path(locale: :en), params: {
        guidebook: { title: "Bad Guide", url: "not-a-url" }
      }
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "must be an http(s) URL"
  end

  test "edit and update guidebook" do
    get edit_admin_guidebook_path(@guidebook, locale: :en)
    assert_response :success

    patch admin_guidebook_path(@guidebook, locale: :en), params: {
      guidebook: { title: "Updated Guide", author: "New Author", url: "https://example.com/updated" }
    }

    assert_redirected_to edit_admin_guidebook_path(@guidebook, locale: :en)
    @guidebook.reload
    assert_equal "Updated Guide", @guidebook.title
    assert_equal "New Author", @guidebook.author
    assert_equal "https://example.com/updated", @guidebook.url
  end

  test "destroy guidebook" do
    assert_difference "Guidebook.count", -1 do
      delete admin_guidebook_path(@guidebook, locale: :en)
    end

    assert_redirected_to admin_guidebooks_path(locale: :en)
  end
end
