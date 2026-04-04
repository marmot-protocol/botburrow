require "application_system_test_case"
require_relative "../support/wnd_stub"

class BotsTest < ApplicationSystemTestCase
  setup do
    @wnd_stub = WndStubFactory.new
    BotsController.wnd_client_class = @wnd_stub
    sign_in
  end

  teardown do
    BotsController.wnd_client_class = Wnd::Client
  end

  test "create a bot and add a command" do
    visit new_bot_path
    fill_in "Name", with: "PingBot"
    fill_in "Description", with: "Responds to /ping"
    click_on "Create Bot"

    assert_text "Bot was successfully created"
    assert_text "PingBot"
    assert_text "Responds to /ping"

    click_on "New command"
    assert_selector "h1", text: "New command"

    fill_in "Name", with: "Ping"
    fill_in "Pattern", with: "/ping"
    fill_in "Response text", with: "pong"
    click_on "Create Command"

    assert_text "Command was successfully created"
    assert_text "/ping"
  end

  test "start and stop a bot" do
    bot = bots(:relay_bot)
    visit bot_path(bot)
    assert_selector "h1", text: bot.name

    click_on "Start"
    assert_text "Bot is starting"

    click_on "Stop"
    assert_text "Bot is stopping"
  end

  test "edit a bot" do
    bot = bots(:relay_bot)
    visit edit_bot_path(bot)

    fill_in "Name", with: "UpdatedBot"
    fill_in "Description", with: "New description"
    click_on "Update Bot"

    assert_text "Bot was successfully updated"
    assert_text "UpdatedBot"
  end

  test "delete a bot" do
    bot = bots(:echo_bot)
    visit bot_path(bot)
    assert_selector "h1", text: bot.name

    accept_confirm("Are you sure?") do
      click_on "Delete", match: :first
    end

    assert_text "Bot was successfully deleted"
  end

  test "bot list shows all bots" do
    visit bots_path

    assert_text "RelayBot"
    assert_text "EchoBot"
  end
end
