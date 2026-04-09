require "test_helper"
require_relative "../support/wnd_stub"

class ChatControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
    @bot = bots(:relay_bot)
    @wnd_stub = WndStubFactory.new
    @wnd_stub.stub_response(:groups_list, [
      { "group" => { "mls_group_id" => { "value" => { "vec" => [1, 2, 3] } }, "name" => "Test Group", "state" => "active", "admin_pubkeys" => [] },
        "membership" => {} }
    ])
    ChatController.wnd_client_class = @wnd_stub
  end

  teardown do
    ChatController.wnd_client_class = Wnd::Client
  end

  test "show renders group cards" do
    get bot_chat_path(@bot)
    assert_response :success
    assert_select "a[href*='group_id']"
  end

  test "show with group_id displays messages for that group" do
    group_id = "testgroup1"
    @bot.message_logs.create!(group_id: group_id, author: "alice", content: "hello", direction: "incoming", message_at: 1.minute.ago)
    @bot.message_logs.create!(group_id: group_id, author: @bot.npub, content: "hi back", direction: "outgoing", message_at: Time.current)

    get bot_chat_path(@bot, group_id: group_id)
    assert_response :success
    assert_select "[data-chat-role='message']", count: 2
  end

  test "show without group_id shows no messages" do
    get bot_chat_path(@bot)
    assert_response :success
    assert_select "[data-chat-role='message']", count: 0
  end

  test "create sends a message and logs it" do
    group_id = "testgroup1"
    assert_difference "MessageLog.count", 1 do
      post bot_chat_path(@bot), params: { group_id: group_id, message: "hello from chat" }
    end

    log = MessageLog.last
    assert_equal group_id, log.group_id
    assert_equal @bot.npub, log.author
    assert_equal "hello from chat", log.content
    assert_equal "outgoing", log.direction

    assert_redirected_to bot_chat_path(@bot, group_id: group_id)
    assert @wnd_stub.called?(:send_message)
  end

  test "unauthenticated user is redirected" do
    sign_out
    get bot_chat_path(@bot)
    assert_redirected_to new_session_path
  end
end
