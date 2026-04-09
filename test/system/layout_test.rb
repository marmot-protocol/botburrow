require "application_system_test_case"
require_relative "../support/wnd_stub"

class LayoutTest < ApplicationSystemTestCase
  setup do
    @wnd_stub = WndStubFactory.new
    BotsController.wnd_client_class = @wnd_stub
    sign_in
  end

  teardown do
    BotsController.wnd_client_class = Wnd::Client
  end

  test "flash notice can be dismissed" do
    bot = bots(:relay_bot)
    visit edit_bot_path(bot)
    fill_in "Name", with: "Updated"
    click_on "Update Bot"

    assert_text "Bot was successfully updated"
    find("[data-action='toast#dismiss']").click
    assert_no_text "Bot was successfully updated"
  end

  test "flash notice auto-dismisses after a few seconds" do
    bot = bots(:relay_bot)
    visit edit_bot_path(bot)
    fill_in "Name", with: "AutoDismiss"
    click_on "Update Bot"

    assert_text "Bot was successfully updated"
    assert_no_text "Bot was successfully updated", wait: 8
  end

  test "sidebar navigation links to bots" do
    visit root_path
    within "nav" do
      assert_link "Bots"
    end
  end

  test "sidebar shows logout button when authenticated" do
    visit root_path
    within "nav" do
      assert_button "Log out"
    end
  end

  test "nested pages show back link to bot" do
    bot = bots(:relay_bot)

    # Command new page
    visit new_bot_command_path(bot)
    back_link = find("a", text: bot.name)
    assert_equal bot_path(bot), URI(back_link[:href]).path

    # Trigger edit page
    trigger = triggers(:keyword_trigger)
    visit edit_bot_trigger_path(bot, trigger)
    back_link = find("a", text: bot.name)
    assert_equal bot_path(bot), URI(back_link[:href]).path

    # Scheduled action new page
    visit new_bot_scheduled_action_path(bot)
    back_link = find("a", text: bot.name)
    assert_equal bot_path(bot), URI(back_link[:href]).path

    # Bot edit page
    visit edit_bot_path(bot)
    back_link = find("a", text: bot.name)
    assert_equal bot_path(bot), URI(back_link[:href]).path
  end

  test "bot detail tabs switch content" do
    bot = bots(:relay_bot)
    visit bot_path(bot)

    # Overview tab visible by default
    assert_selector "[data-tabs-target='panel'][id='overview']", visible: true

    # Click Commands tab
    click_on "Commands"
    assert_selector "[data-tabs-target='panel'][id='commands']", visible: true
    assert_selector "[data-tabs-target='panel'][id='overview']", visible: false

    # Click Logs tab
    click_on "Logs"
    assert_selector "[data-tabs-target='panel'][id='logs']", visible: true
    assert_selector "[data-tabs-target='panel'][id='commands']", visible: false
  end
end
