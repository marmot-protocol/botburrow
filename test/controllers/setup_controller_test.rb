require "test_helper"

class SetupControllerTest < ActionDispatch::IntegrationTest
  test "setup page is accessible when no users exist" do
    User.delete_all

    get new_setup_path
    assert_response :success
  end

  test "setup page redirects to root when users exist" do
    get new_setup_path
    assert_redirected_to root_path
  end

  test "setup creates a user and starts a session" do
    User.delete_all

    assert_difference "User.count", 1 do
      post setup_path, params: { user: {
        email_address: "admin@example.com",
        password: "securepassword123",
        password_confirmation: "securepassword123"
      } }
    end

    assert_redirected_to root_path
    assert cookies[:session_id].present?
  end

  test "setup validates email and password presence" do
    User.delete_all

    assert_no_difference "User.count" do
      post setup_path, params: { user: {
        email_address: "",
        password: "",
        password_confirmation: ""
      } }
    end

    assert_response :unprocessable_entity
  end

  test "setup redirects create to root when users exist" do
    post setup_path, params: { user: {
      email_address: "sneaky@example.com",
      password: "password123",
      password_confirmation: "password123"
    } }

    assert_redirected_to root_path
  end

  test "login page works after setup" do
    get new_session_path
    assert_response :success
  end

  test "health check is accessible without auth" do
    get rails_health_check_path
    assert_response :success
  end

  test "unauthenticated request redirects to setup when no users exist" do
    User.delete_all

    get root_path
    assert_redirected_to new_setup_path
  end

  test "unauthenticated request redirects to login when users exist" do
    get root_path
    assert_redirected_to new_session_path
  end
end
