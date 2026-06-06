require "test_helper"
require "base64"
require "securerandom"
require "stringio"

class CdnUrlGenerationTest < ActionView::TestCase
  include SharedHelper
  include Rails.application.routes.url_helpers

  PNG_FIXTURE = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII="

  self.fixture_table_names = []

  setup do
    @original_asset_host = Rails.application.config.asset_host
    @original_action_controller_asset_host = ActionController::Base.asset_host
    Rails.application.config.asset_host = "https://assets.austrian.rocks"
    ActionController::Base.asset_host = "https://assets.austrian.rocks"

    @region = Region.create!(
      name: "CDN test",
      slug: "cdn-test-#{SecureRandom.hex(4)}",
      published: true
    )
    @region.cover.attach(
      io: StringIO.new(Base64.decode64(PNG_FIXTURE)),
      filename: "cdn-test.png",
      content_type: "image/png"
    )
  end

  teardown do
    @region.cover.purge if @region&.cover&.attached?
    @region.destroy if @region&.persisted?
    Rails.application.config.asset_host = @original_asset_host
    ActionController::Base.asset_host = @original_action_controller_asset_host
  end

  test "static asset URLs use the explicit HTTPS CDN host" do
    assert asset_url("tailwind.css").start_with?("https://assets.austrian.rocks/")
  end

  test "blob proxy URLs use the explicit HTTPS CDN host" do
    with_production_style_url_generation do
      url = cdn_image_url(@region.cover.blob)

      assert url.start_with?("https://assets.austrian.rocks/rails/active_storage/blobs/proxy/"), url
    end
  end

  test "variant proxy URLs use the explicit HTTPS CDN host" do
    with_production_style_url_generation do
      url = cdn_image_url(@region.cover.variant(:thumb))

      assert url.start_with?("https://assets.austrian.rocks/rails/active_storage/representations/proxy/"), url
    end
  end

  test "test storage can generate local blob paths without Bunny credentials" do
    Rails.application.config.asset_host = "https://assets.austrian.rocks"

    path = Rails.application.routes.url_helpers.rails_blob_path(@region.cover.blob, only_path: true)

    assert path.start_with?("/rails/active_storage/blobs/")
  end

  private

  def with_production_style_url_generation
    singleton_class = class << Rails.env; self; end
    original_local = Rails.env.method(:local?)
    singleton_class.define_method(:local?) { false }

    yield
  ensure
    singleton_class.define_method(:local?, original_local)
  end
end
