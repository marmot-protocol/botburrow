require "application_system_test_case"
require_relative "../support/wnd_stub"

class MessageLogsTest < ApplicationSystemTestCase
  setup do
    @wnd_stub = WndStubFactory.new
    BotsController.wnd_client_class = @wnd_stub
    sign_in
    @bot = bots(:relay_bot)
  end

  teardown do
    BotsController.wnd_client_class = Wnd::Client
  end

  test "view message logs" do
    @bot.message_logs.create!(
      group_id: "group123",
      author: "npub1sender",
      content: "/ping",
      direction: "incoming",
      message_at: 1.hour.ago
    )
    @bot.message_logs.create!(
      group_id: "group123",
      author: @bot.npub,
      content: "pong",
      direction: "outgoing",
      message_at: 1.hour.ago + 1.second
    )

    visit bot_message_logs_path(@bot)
    assert_selector "h1", text: "Message Logs"

    assert_text "/ping"
    assert_text "pong"
    assert_text "Incoming"
    assert_text "Outgoing"
  end

  test "error entries display with distinctive styling" do
    @bot.message_logs.create!(
      group_id: "group123",
      author: "system",
      content: "Script error: RuntimeError: something broke",
      direction: "error",
      message_at: 1.hour.ago
    )

    visit bot_message_logs_path(@bot)
    assert_text "Script error: RuntimeError: something broke"
    assert_selector "span.text-danger", text: "Error"
  end

  test "error filter option works in direction dropdown" do
    @bot.message_logs.create!(
      group_id: "group123",
      author: "npub1sender",
      content: "/ping",
      direction: "incoming",
      message_at: 2.hours.ago
    )
    @bot.message_logs.create!(
      group_id: "group123",
      author: "system",
      content: "Script error: NameError: undefined",
      direction: "error",
      message_at: 1.hour.ago
    )

    # Visit with filter pre-applied to verify controller filtering works
    visit bot_message_logs_path(@bot, direction: "error")

    assert_text "Script error"
    assert_no_text "/ping"
    assert_selector "span.text-danger", text: "Error"
  end

  test "message log link on bot show page" do
    visit bot_path(@bot)
    click_on "Logs"
    assert_text "Message Logs"
  end
end
