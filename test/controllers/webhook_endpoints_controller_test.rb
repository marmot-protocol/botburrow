require "test_helper"

class WebhookEndpointsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
    @bot = bots(:relay_bot)
    @endpoint = @bot.webhook_endpoints.create!(name: "Test Hook", url: "https://example.com/hook", secret: "s3cret")
  end

  # -- Authentication --

  test "unauthenticated user is redirected to login" do
    sign_out
    get new_bot_webhook_endpoint_path(@bot)
    assert_redirected_to new_session_path
  end

  # -- Index --

  test "index lists webhook endpoints" do
    get bot_webhook_endpoints_path(@bot)
    assert_response :success
    assert_select "td", "Test Hook"
    assert_select "td", "https://example.com/hook"
  end

  # -- New / Create --

  test "new form renders" do
    get new_bot_webhook_endpoint_path(@bot)
    assert_response :success
    assert_select "form" do
      assert_select "input[name='webhook_endpoint[name]']"
      assert_select "input[name='webhook_endpoint[url]']"
      assert_select "input[name='webhook_endpoint[secret]']"
      assert_select "input[name='webhook_endpoint[enabled]']"
    end
  end

  test "creating an endpoint saves and redirects" do
    assert_difference "WebhookEndpoint.count", 1 do
      post bot_webhook_endpoints_path(@bot), params: {
        webhook_endpoint: { name: "New Hook", url: "https://example.com/new", secret: "abc", enabled: "1" }
      }
    end

    endpoint = WebhookEndpoint.last
    assert_equal "New Hook", endpoint.name
    assert_equal "https://example.com/new", endpoint.url
    assert_equal "abc", endpoint.secret
    assert endpoint.enabled?
    assert_redirected_to bot_path(@bot)
  end

  test "creating with invalid data re-renders form" do
    assert_no_difference "WebhookEndpoint.count" do
      post bot_webhook_endpoints_path(@bot), params: {
        webhook_endpoint: { name: "", url: "" }
      }
    end

    assert_response :unprocessable_entity
  end

  # -- Edit / Update --

  test "edit form renders" do
    get edit_bot_webhook_endpoint_path(@bot, @endpoint)
    assert_response :success
    assert_select "input[name='webhook_endpoint[name]'][value='Test Hook']"
  end

  test "updating an endpoint changes attributes" do
    patch bot_webhook_endpoint_path(@bot, @endpoint), params: {
      webhook_endpoint: { name: "Updated Hook", url: "https://example.com/updated" }
    }

    assert_redirected_to bot_path(@bot)
    @endpoint.reload
    assert_equal "Updated Hook", @endpoint.name
    assert_equal "https://example.com/updated", @endpoint.url
  end

  test "updating with invalid data re-renders form" do
    patch bot_webhook_endpoint_path(@bot, @endpoint), params: {
      webhook_endpoint: { name: "" }
    }

    assert_response :unprocessable_entity
  end

  # -- Destroy --

  test "destroying an endpoint deletes and redirects" do
    assert_difference "WebhookEndpoint.count", -1 do
      delete bot_webhook_endpoint_path(@bot, @endpoint)
    end

    assert_redirected_to bot_path(@bot)
  end
end
