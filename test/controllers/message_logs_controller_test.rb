require "test_helper"

class MessageLogsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
    @bot = bots(:relay_bot)

    @incoming = @bot.message_logs.create!(
      group_id: "group1", author: "npub1alice", content: "Hello bot",
      direction: "incoming", message_at: 2.minutes.ago
    )
    @outgoing = @bot.message_logs.create!(
      group_id: "group1", author: @bot.npub, content: "Hello back",
      direction: "outgoing", message_at: 1.minute.ago
    )
    @other_group = @bot.message_logs.create!(
      group_id: "group2", author: "npub1bob", content: "Hi there",
      direction: "incoming", message_at: 30.seconds.ago
    )
  end

  test "index shows message logs" do
    get bot_message_logs_path(@bot)
    assert_response :success
    assert_select "table" do
      assert_select "tr", minimum: 3 # 3 logs
    end
  end

  test "index requires authentication" do
    sign_out
    get bot_message_logs_path(@bot)
    assert_redirected_to new_session_path
  end

  test "index filters by group_id" do
    get bot_message_logs_path(@bot), params: { group_id: "group2" }
    assert_response :success
    assert_select "td", text: /Hi there/
    assert_select "td", text: /Hello bot/, count: 0
  end

  test "index filters by direction" do
    get bot_message_logs_path(@bot), params: { direction: "outgoing" }
    assert_response :success
    assert_select "td", text: /Hello back/
    assert_select "td", text: /Hello bot/, count: 0
  end

  test "index filters by both group_id and direction" do
    get bot_message_logs_path(@bot), params: { group_id: "group1", direction: "incoming" }
    assert_response :success
    assert_select "td", text: /Hello bot/
    assert_select "td", text: /Hello back/, count: 0
    assert_select "td", text: /Hi there/, count: 0
  end

  test "index orders by most recent first" do
    get bot_message_logs_path(@bot)
    assert_response :success
    # The most recent log (other_group) should appear first in the table body
    assert_select "tbody tr:first-child td", text: /Hi there/
  end

  test "index limits to 100 logs" do
    101.times do |i|
      @bot.message_logs.create!(
        group_id: "bulk", author: "a", content: "msg#{i}",
        direction: "incoming", message_at: i.seconds.ago
      )
    end

    get bot_message_logs_path(@bot)
    assert_response :success
    # 100 + the 3 existing = 103, but limited to 100
    assert_select "tbody tr", count: 100
  end
end
