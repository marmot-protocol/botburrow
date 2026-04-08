require "application_system_test_case"

class SetupTest < ApplicationSystemTestCase
  test "first-run setup creates admin and redirects to dashboard" do
    User.delete_all

    visit root_path
    assert_current_path new_setup_path

    assert_text "Create your admin account to get started"
    fill_in "Email", with: "admin@botburrow.local"
    fill_in "user_password", with: "securepassword"
    fill_in "user_password_confirmation", with: "securepassword"
    click_on "Create Account"

    assert_current_path root_path
    assert_text "Bots"
  end

  test "unauthenticated user is redirected to login" do
    visit root_path
    assert_current_path new_session_path
  end
end
