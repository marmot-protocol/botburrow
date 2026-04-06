require "application_system_test_case"
require_relative "../support/wnd_stub"

class WebhookEndpointsTest < ApplicationSystemTestCase
  setup do
    @wnd_stub = WndStubFactory.new
    BotsController.wnd_client_class = @wnd_stub
    sign_in
    @bot = bots(:relay_bot)
  end

  teardown do
    BotsController.wnd_client_class = Wnd::Client
  end

  test "create a webhook endpoint" do
    visit new_bot_webhook_endpoint_path(@bot)
    assert_selector "h1", text: "New webhook endpoint"

    fill_in "Name", with: "My API"
    fill_in "Url", with: "https://example.com/webhook"
    fill_in "Secret", with: "mysecret123"
    click_on "Create Webhook endpoint"

    assert_text "Webhook endpoint was successfully created"
    assert_text "My API"
  end

  test "edit a webhook endpoint" do
    endpoint = @bot.webhook_endpoints.create!(
      name: "Old Webhook",
      url: "https://old.example.com/hook",
      enabled: true
    )

    visit edit_bot_webhook_endpoint_path(@bot, endpoint)
    fill_in "Name", with: "Updated Webhook"
    fill_in "Url", with: "https://new.example.com/hook"
    click_on "Update Webhook endpoint"

    assert_text "Webhook endpoint was successfully updated"
    assert_text "Updated Webhook"
  end

  test "webhook endpoints appear on bot show page" do
    @bot.webhook_endpoints.create!(
      name: "Notification Hook",
      url: "https://hooks.example.com/notify",
      enabled: true
    )

    visit bot_path(@bot)
    assert_text "Webhook Endpoints"
    assert_text "Notification Hook"
    assert_text "hooks.example.com"
  end
end
