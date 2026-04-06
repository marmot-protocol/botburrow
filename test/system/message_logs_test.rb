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
    assert_text "incoming"
    assert_text "outgoing"
  end

  test "message log link on bot show page" do
    visit bot_path(@bot)
    assert_text "View message logs"
  end
end
