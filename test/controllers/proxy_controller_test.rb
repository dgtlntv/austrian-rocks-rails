require "test_helper"
require "base64"
require "securerandom"
require "stringio"

class ProxyControllerTest < ActionDispatch::IntegrationTest
  PNG_FIXTURE = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII="

  self.fixture_table_names = []

  setup do
    @topo = Topo.new(published: true)
    @topo.photo.attach(
      io: StringIO.new(Base64.decode64(PNG_FIXTURE)),
      filename: "topo-test.png",
      content_type: "image/png"
    )
    @topo.save!
  end

  teardown do
    @topo.photo.purge if @topo&.photo&.attached?
    @topo.destroy if @topo&.persisted?
  end

  test "topo proxy returns a public cacheable response for an existing topo" do
    get topo_proxy_path(@topo)

    assert_response :success
    cache_control = response.headers.fetch("Cache-Control")
    assert_includes cache_control, "public"
    assert_match(/max-age=|immutable/, cache_control)
  end

  test "topo proxy returns not found for a missing topo" do
    missing_id = Topo.maximum(:id).to_i + 1000

    get topo_proxy_path(missing_id)

    assert_response :not_found
  end
end
