require "test_helper"
require_relative "../support/mock_listener_wnd"

class MockWndFactory
  def initialize(mock)
    @mock = mock
  end

  def new(**_kwargs)
    @mock
  end
end

class BotListenerTest < ActiveSupport::TestCase
  setup do
    @wnd = MockListenerWnd.new
    @factory = MockWndFactory.new(@wnd)
    @listener = BotListener.new(wnd_class: @factory, sync_interval: 0.05)
  end

  teardown do
    @listener.shutdown
    @wnd.disconnect_all
    sleep 0.2
  end

  test "reconciles stale bot statuses on startup" do
    bot_running = Bot.create!(name: "Runner", npub: "npub1runner#{SecureRandom.hex(10)}", status: :running, error_message: "stale")
    bot_stopped = Bot.create!(name: "Stopped", npub: "npub1stopped#{SecureRandom.hex(10)}", status: :stopped)

    run_listener_briefly

    assert_equal "stopped", bot_running.reload.status
    assert_nil bot_running.error_message
    assert_equal "stopped", bot_stopped.reload.status
  end

  test "transitions starting bots to running" do
    npub = SecureRandom.hex(32)
    bot = Bot.create!(name: "TestBot", npub: npub, status: :stopped)
    @wnd.add_group(npub, "group1")

    listener_thread = Thread.new { @listener.run }
    sleep 0.1

    bot.update!(status: :starting)
    sleep 0.3

    @listener.shutdown
    @wnd.disconnect_all
    listener_thread.join(2)

    assert_equal "running", bot.reload.status
  end

  test "transitions stopping bots to stopped" do
    npub = SecureRandom.hex(32)
    bot = Bot.create!(name: "TestBot", npub: npub, status: :stopped)
    @wnd.add_group(npub, "group1")

    listener_thread = Thread.new { @listener.run }
    sleep 0.1

    bot.update!(status: :starting)
    sleep 0.3
    bot.update!(status: :stopping)
    sleep 0.3

    @listener.shutdown
    @wnd.disconnect_all
    listener_thread.join(2)

    assert_equal "stopped", bot.reload.status
  end

  test "dispatches matching command response for new message" do
    npub = SecureRandom.hex(32)
    group_id = "testgroup123"
    bot = Bot.create!(name: "MsgBot", npub: npub, status: :stopped)
    bot.commands.create!(name: "Ping", pattern: "/ping", response_text: "pong!", enabled: true)
    @wnd.add_group(npub, group_id)

    listener_thread = Thread.new { @listener.run }
    sleep 0.1
    bot.update!(status: :starting)
    sleep 0.3

    @wnd.emit_event(npub, group_id, {
      "trigger" => "NewMessage",
      "message" => { "content" => "/ping", "author" => "otherpubkey123" }
    })
    sleep 0.3

    @listener.shutdown
    @wnd.disconnect_all
    listener_thread.join(2)

    send_calls = @wnd.calls_for(:send_message)
    assert_equal 1, send_calls.size
    _, args = send_calls.first
    assert_equal npub, args[:account]
    assert_equal group_id, args[:group_id]
    assert_equal "pong!", args[:message]
  end

  test "skips own messages" do
    npub = SecureRandom.hex(32)
    group_id = "echogroup"
    bot = Bot.create!(name: "EchoBot", npub: npub, status: :stopped)
    bot.commands.create!(name: "Ping", pattern: "/ping", response_text: "pong!", enabled: true)
    @wnd.add_group(npub, group_id)

    listener_thread = Thread.new { @listener.run }
    sleep 0.1
    bot.update!(status: :starting)
    sleep 0.3

    @wnd.emit_event(npub, group_id, {
      "trigger" => "NewMessage",
      "message" => { "content" => "/ping", "author" => npub }
    })
    sleep 0.3

    @listener.shutdown
    @wnd.disconnect_all
    listener_thread.join(2)

    assert_empty @wnd.calls_for(:send_message)
  end

  test "ignores initial messages" do
    npub = SecureRandom.hex(32)
    group_id = "historygroup"
    bot = Bot.create!(name: "HistBot", npub: npub, status: :stopped)
    bot.commands.create!(name: "Ping", pattern: "/ping", response_text: "pong!", enabled: true)
    @wnd.add_group(npub, group_id)

    listener_thread = Thread.new { @listener.run }
    sleep 0.1
    bot.update!(status: :starting)
    sleep 0.3

    @wnd.emit_event(npub, group_id, {
      "trigger" => "InitialMessage",
      "message" => { "content" => "/ping", "author" => "other" }
    })
    sleep 0.3

    @listener.shutdown
    @wnd.disconnect_all
    listener_thread.join(2)

    assert_empty @wnd.calls_for(:send_message)
  end

  test "records heartbeat while running" do
    run_listener_briefly(duration: 0.2)

    heartbeat = Setting["listener.heartbeat"]
    assert_not_nil heartbeat
    assert_in_delta Time.current, Time.parse(heartbeat), 5
  end

  private

  def run_listener_briefly(duration: 0.15)
    thread = Thread.new { @listener.run }
    sleep duration
    @listener.shutdown
    @wnd.disconnect_all
    thread.join(2)
  end
end
