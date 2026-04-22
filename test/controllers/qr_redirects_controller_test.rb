require "test_helper"

class QrRedirectsControllerTest < ActionDispatch::IntegrationTest
  test "should get show" do
    get qr_redirects_show_url
    assert_response :success
  end
end
