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

    click_on "Commands"
    click_on "New command"
    assert_selector "h1", text: "New command"

    fill_in "Name", with: "Ping"
    fill_in "Pattern", with: "/ping"
    page.execute_script("document.querySelector(\"textarea[name='command[response_text]']\").value = '\"pong\"'")
    click_on "Create Command"

    assert_text "Command was successfully created"
    click_on "Commands"
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

  test "bot show page has turbo stream subscription for live status updates" do
    bot = bots(:relay_bot)
    visit bot_path(bot)

    # Verify the page subscribes to a bot-specific Turbo Stream
    assert_selector "turbo-cable-stream-source", visible: false

    # Verify the status bar has the correct replaceable target ID
    assert_selector "#status_bot_#{bot.id}"

    # Verify the status detail in the overview tab has the correct target ID
    assert_selector "#status_detail_bot_#{bot.id}"
  end

  test "bot status bar shows correct buttons for each state" do
    bot = bots(:relay_bot)

    # Stopped: should show Start button
    visit bot_path(bot)
    assert_text "Stopped"
    assert_button "Start"
    assert_no_button "Stop"

    # Starting: should show Stop button
    click_on "Start"
    assert_text "Starting"
    assert_button "Stop"
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

    page.execute_script("document.querySelector('form[action*=\"bots/#{bot.id}\"][method=\"post\"] input[name=\"_method\"][value=\"delete\"]').closest('form').requestSubmit()")

    assert_text "Bot was successfully deleted"
  end

  test "create a script command via the UI" do
    bot = bots(:relay_bot)
    visit new_bot_command_path(bot)
    assert_selector "h1", text: "New command"

    fill_in "Name", with: "Coin Flip"
    fill_in "Pattern", with: "/flip"
    # CodeMirror hides the textarea; set value via JS for form submission
    page.execute_script("document.querySelector(\"textarea[name='command[response_text]']\").value = '%w[Heads Tails].sample'")
    click_on "Create Command"

    assert_text "Command was successfully created"
  end

  test "bot list shows all bots" do
    visit bots_path

    assert_text "RelayBot"
    assert_text "EchoBot"
  end

  test "status bar updates live via Turbo Streams when status changes" do
    bot = bots(:relay_bot)
    visit bot_path(bot)

    assert_text "Stopped"
    assert_selector "#status_bot_#{bot.id}"

    # Simulate what the BotListener does: update status from another "process"
    # The test adapter (which extends async) delivers in-process broadcasts
    bot.update!(status: :running)

    # The broadcast should replace the status bar without a page refresh
    assert_text "Running", wait: 5
    assert_button "Stop", wait: 2
    assert_no_button "Start"
  end

  test "status detail updates live via Turbo Streams when status changes" do
    bot = bots(:relay_bot)
    visit bot_path(bot)

    assert_selector "#status_detail_bot_#{bot.id}"
    within("#status_detail_bot_#{bot.id}") do
      assert_text "Stopped"
    end

    bot.update!(status: :running)

    within("#status_detail_bot_#{bot.id}", wait: 5) do
      assert_text "Running"
    end
  end

  test "index page bot card updates live via Turbo Streams when status changes" do
    bot = bots(:relay_bot)
    visit bots_path

    assert_selector "##{ActionView::RecordIdentifier.dom_id(bot)}"
    within("##{ActionView::RecordIdentifier.dom_id(bot)}") do
      assert_text "Stopped"
    end

    bot.update!(status: :running)

    within("##{ActionView::RecordIdentifier.dom_id(bot)}", wait: 5) do
      assert_text "Running"
    end
  end
end
