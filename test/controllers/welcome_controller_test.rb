require "test_helper"

class WelcomeControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get root_localized_url(locale: I18n.default_locale)
    assert_response :success
  end
end
