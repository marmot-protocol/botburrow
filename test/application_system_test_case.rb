require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 900 ]

  def sign_in
    user = users(:one)
    visit new_session_path
    fill_in "Enter your email address", with: user.email_address
    fill_in "Enter your password", with: "password"
    click_on "Sign in"
    assert_text "Bots" # verify login succeeded
  end
end
