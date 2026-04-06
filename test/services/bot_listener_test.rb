require "test_helper"
require "webmock/minitest"
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
    @lock_path = Rails.root.join("tmp", "pids", "listener_test_#{SecureRandom.hex(4)}.lock")
    @listener = BotListener.new(wnd_class: @factory, sync_interval: 0.05, min_reply_delay: 0, lock_path: @lock_path)
  end

  teardown do
    @listener.shutdown
    @wnd.disconnect_all
    sleep 0.2
    @lock_path.delete if @lock_path.exist?
  end

  test "second listener instance raises when another is already running" do
    lock_path = Rails.root.join("tmp", "pids", "listener_test.lock")

    first = BotListener.new(wnd_class: @factory, sync_interval: 0.05, min_reply_delay: 0, lock_path: lock_path)
    first_thread = Thread.new { first.run }
    sleep 0.1

    second = BotListener.new(wnd_class: @factory, sync_interval: 0.05, min_reply_delay: 0, lock_path: lock_path)
    assert_raises(BotListener::AlreadyRunningError) { second.run }

    first.shutdown
    @wnd.disconnect_all
    first_thread.join(2)
  ensure
    lock_path&.delete if lock_path&.exist?
  end

  test "lock is released after listener shuts down allowing restart" do
    lock_path = Rails.root.join("tmp", "pids", "listener_restart_test.lock")

    first = BotListener.new(wnd_class: @factory, sync_interval: 0.05, min_reply_delay: 0, lock_path: lock_path)
    first_thread = Thread.new { first.run }
    sleep 0.1
    first.shutdown
    @wnd.disconnect_all
    first_thread.join(2)

    # Should be able to start a new listener after the first one stopped
    second = BotListener.new(wnd_class: @factory, sync_interval: 0.05, min_reply_delay: 0, lock_path: lock_path)
    second_thread = Thread.new { second.run }
    sleep 0.1
    second.shutdown
    @wnd.disconnect_all
    second_thread.join(2)

    # If we got here without raising AlreadyRunningError, the lock was properly released
    assert true
  ensure
    lock_path&.delete if lock_path&.exist?
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

  # Slice 5: Listener dispatches to triggers when no command matches
  test "dispatches trigger reply when no command matches" do
    npub = SecureRandom.hex(32)
    group_id = "triggergroup1"
    bot = Bot.create!(name: "TrigBot", npub: npub, status: :stopped)
    bot.commands.create!(name: "Ping", pattern: "/ping", response_text: "pong!", enabled: true)
    bot.triggers.create!(
      name: "Hello trigger",
      event_type: :message_received,
      condition_type: :keyword,
      condition_value: "hello",
      action_type: :reply,
      action_config: '{"response_text": "Hello back!"}',
      position: 1,
      enabled: true
    )
    @wnd.add_group(npub, group_id)

    listener_thread = Thread.new { @listener.run }
    sleep 0.1
    bot.update!(status: :starting)
    sleep 0.3

    # Send a message that does NOT match any command but DOES match the trigger
    @wnd.emit_event(npub, group_id, {
      "trigger" => "NewMessage",
      "message" => { "content" => "hello world", "author" => "otherpubkey123" }
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
    assert_equal "Hello back!", args[:message]
  end

  # Slice 6: First-match-wins for triggers ordered by position
  test "first matching trigger wins based on position" do
    npub = SecureRandom.hex(32)
    group_id = "orderedgroup"
    bot = Bot.create!(name: "OrderBot", npub: npub, status: :stopped)
    bot.triggers.create!(
      name: "Catch-all",
      event_type: :message_received,
      condition_type: :any,
      condition_value: nil,
      action_type: :reply,
      action_config: '{"response_text": "Catch-all response"}',
      position: 2,
      enabled: true
    )
    bot.triggers.create!(
      name: "Hello trigger",
      event_type: :message_received,
      condition_type: :keyword,
      condition_value: "hello",
      action_type: :reply,
      action_config: '{"response_text": "Hello first!"}',
      position: 1,
      enabled: true
    )
    @wnd.add_group(npub, group_id)

    listener_thread = Thread.new { @listener.run }
    sleep 0.1
    bot.update!(status: :starting)
    sleep 0.3

    @wnd.emit_event(npub, group_id, {
      "trigger" => "NewMessage",
      "message" => { "content" => "hello there", "author" => "otherpubkey" }
    })
    sleep 0.3

    @listener.shutdown
    @wnd.disconnect_all
    listener_thread.join(2)

    send_calls = @wnd.calls_for(:send_message)
    assert_equal 1, send_calls.size
    _, args = send_calls.first
    assert_equal "Hello first!", args[:message]
  end

  test "disabled triggers are skipped" do
    npub = SecureRandom.hex(32)
    group_id = "disabledgroup"
    bot = Bot.create!(name: "DisabledBot", npub: npub, status: :stopped)
    bot.triggers.create!(
      name: "Disabled hello",
      event_type: :message_received,
      condition_type: :keyword,
      condition_value: "hello",
      action_type: :reply,
      action_config: '{"response_text": "Should not fire"}',
      position: 1,
      enabled: false
    )
    @wnd.add_group(npub, group_id)

    listener_thread = Thread.new { @listener.run }
    sleep 0.1
    bot.update!(status: :starting)
    sleep 0.3

    @wnd.emit_event(npub, group_id, {
      "trigger" => "NewMessage",
      "message" => { "content" => "hello", "author" => "otherpubkey" }
    })
    sleep 0.3

    @listener.shutdown
    @wnd.disconnect_all
    listener_thread.join(2)

    assert_empty @wnd.calls_for(:send_message)
  end

  test "log_only trigger does not send a reply" do
    npub = SecureRandom.hex(32)
    group_id = "loggroup"
    bot = Bot.create!(name: "LogBot", npub: npub, status: :stopped)
    bot.triggers.create!(
      name: "Log everything",
      event_type: :message_received,
      condition_type: :any,
      condition_value: nil,
      action_type: :log_only,
      position: 1,
      enabled: true
    )
    @wnd.add_group(npub, group_id)

    listener_thread = Thread.new { @listener.run }
    sleep 0.1
    bot.update!(status: :starting)
    sleep 0.3

    @wnd.emit_event(npub, group_id, {
      "trigger" => "NewMessage",
      "message" => { "content" => "something", "author" => "otherpubkey" }
    })
    sleep 0.3

    @listener.shutdown
    @wnd.disconnect_all
    listener_thread.join(2)

    assert_empty @wnd.calls_for(:send_message)
  end

  # -- Built-in commands --

  test "built-in /help lists enabled commands" do
    npub = SecureRandom.hex(32)
    group_id = "helpgroup"
    bot = Bot.create!(name: "HelpBot", npub: npub, status: :stopped)
    bot.commands.create!(name: "Ping", pattern: "/ping", response_text: "pong!", enabled: true)
    bot.commands.create!(name: "Secret", pattern: "/secret", response_text: "hidden", enabled: false)
    @wnd.add_group(npub, group_id)

    listener_thread = Thread.new { @listener.run }
    sleep 0.1
    bot.update!(status: :starting)
    sleep 0.3

    @wnd.emit_event(npub, group_id, {
      "trigger" => "NewMessage",
      "message" => { "content" => "/help", "author" => "otherpubkey" }
    })
    sleep 0.3

    @listener.shutdown
    @wnd.disconnect_all
    listener_thread.join(2)

    send_calls = @wnd.calls_for(:send_message)
    assert_equal 1, send_calls.size
    _, args = send_calls.first
    assert_includes args[:message], "/ping"
    assert_includes args[:message], "Ping"
    assert_not_includes args[:message], "Secret"
  end

  test "built-in /status shows bot info" do
    npub = SecureRandom.hex(32)
    group_id = "statusgroup"
    bot = Bot.create!(name: "StatusBot", npub: npub, status: :stopped)
    bot.commands.create!(name: "Ping", pattern: "/ping", response_text: "pong!", enabled: true)
    @wnd.add_group(npub, group_id)

    listener_thread = Thread.new { @listener.run }
    sleep 0.1
    bot.update!(status: :starting)
    sleep 0.3

    @wnd.emit_event(npub, group_id, {
      "trigger" => "NewMessage",
      "message" => { "content" => "/status", "author" => "otherpubkey" }
    })
    sleep 0.3

    @listener.shutdown
    @wnd.disconnect_all
    listener_thread.join(2)

    send_calls = @wnd.calls_for(:send_message)
    assert_equal 1, send_calls.size
    _, args = send_calls.first
    assert_includes args[:message], "StatusBot"
    assert_includes args[:message], "1"  # 1 enabled command
  end

  # -- Template response type --

  test "dispatches template response with variable interpolation" do
    npub = SecureRandom.hex(32)
    group_id = "templategroup"
    bot = Bot.create!(name: "TplBot", npub: npub, status: :stopped)
    bot.commands.create!(
      name: "Greet",
      pattern: "/greet",
      response_text: "Hello {{author}}, you said: {{args}}. I am {{bot_name}}.",
      response_type: :template,
      enabled: true
    )
    @wnd.add_group(npub, group_id)

    listener_thread = Thread.new { @listener.run }
    sleep 0.1
    bot.update!(status: :starting)
    sleep 0.3

    @wnd.emit_event(npub, group_id, {
      "trigger" => "NewMessage",
      "message" => { "content" => "/greet world", "author" => "alice123" }
    })
    sleep 0.3

    @listener.shutdown
    @wnd.disconnect_all
    listener_thread.join(2)

    send_calls = @wnd.calls_for(:send_message)
    assert_equal 1, send_calls.size
    _, args = send_calls.first
    assert_includes args[:message], "Hello alice123"
    assert_includes args[:message], "you said: world"
    assert_includes args[:message], "I am TplBot"
  end

  # -- Webhook response type --

  test "webhook command dispatches to webhook and sends response" do
    npub = SecureRandom.hex(32)
    group_id = "webhookgroup"
    bot = Bot.create!(name: "HookBot", npub: npub, status: :stopped)
    endpoint = bot.webhook_endpoints.create!(name: "CMD Hook", url: "https://example.com/hook", enabled: true)
    bot.commands.create!(
      name: "Ask",
      pattern: "/ask",
      response_text: endpoint.url,
      response_type: :webhook,
      enabled: true
    )
    @wnd.add_group(npub, group_id)

    # Stub the HTTP call
    stub_request(:post, "https://example.com/hook")
      .to_return(status: 200, body: "Webhook says hello!")

    listener_thread = Thread.new { @listener.run }
    sleep 0.1
    bot.update!(status: :starting)
    sleep 0.3

    @wnd.emit_event(npub, group_id, {
      "trigger" => "NewMessage",
      "message" => { "content" => "/ask something", "author" => "alice" }
    })
    sleep 0.5

    @listener.shutdown
    @wnd.disconnect_all
    listener_thread.join(2)

    send_calls = @wnd.calls_for(:send_message)
    assert_equal 1, send_calls.size
    _, args = send_calls.first
    assert_equal "Webhook says hello!", args[:message]

    # Verify delivery was logged
    assert_equal 1, WebhookDelivery.count
    delivery = WebhookDelivery.last
    assert delivery.success?
  end

  test "records heartbeat while running" do
    run_listener_briefly(duration: 0.2)

    heartbeat = Setting["listener.heartbeat"]
    assert_not_nil heartbeat
    assert_in_delta Time.current, Time.parse(heartbeat), 5
  end

  # -- Message logging --

  test "logs incoming message" do
    npub = SecureRandom.hex(32)
    group_id = "loggroup1"
    bot = Bot.create!(name: "LogBot", npub: npub, status: :stopped)
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

    incoming = bot.message_logs.incoming
    assert_equal 1, incoming.count
    log = incoming.first
    assert_equal group_id, log.group_id
    assert_equal "otherpubkey123", log.author
    assert_equal "/ping", log.content
    assert_equal "incoming", log.direction
  end

  test "logs outgoing response for matched command" do
    npub = SecureRandom.hex(32)
    group_id = "loggroup2"
    bot = Bot.create!(name: "LogBot2", npub: npub, status: :stopped)
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

    outgoing = bot.message_logs.outgoing
    assert_equal 1, outgoing.count
    log = outgoing.first
    assert_equal group_id, log.group_id
    assert_equal bot.npub, log.author
    assert_equal "pong!", log.content
    assert_equal "outgoing", log.direction
  end

  test "logs outgoing response for built-in /help command" do
    npub = SecureRandom.hex(32)
    group_id = "loghelp"
    bot = Bot.create!(name: "HelpLogBot", npub: npub, status: :stopped)
    @wnd.add_group(npub, group_id)

    listener_thread = Thread.new { @listener.run }
    sleep 0.1
    bot.update!(status: :starting)
    sleep 0.3

    @wnd.emit_event(npub, group_id, {
      "trigger" => "NewMessage",
      "message" => { "content" => "/help", "author" => "otherpubkey" }
    })
    sleep 0.3

    @listener.shutdown
    @wnd.disconnect_all
    listener_thread.join(2)

    outgoing = bot.message_logs.outgoing
    assert_equal 1, outgoing.count
    assert_includes outgoing.first.content, "Available commands"
  end

  test "logs outgoing response for trigger reply" do
    npub = SecureRandom.hex(32)
    group_id = "logtrigger"
    bot = Bot.create!(name: "TrigLogBot", npub: npub, status: :stopped)
    bot.triggers.create!(
      name: "Hello",
      event_type: :message_received,
      condition_type: :keyword,
      condition_value: "hello",
      action_type: :reply,
      action_config: '{"response_text": "Hello back!"}',
      position: 1,
      enabled: true
    )
    @wnd.add_group(npub, group_id)

    listener_thread = Thread.new { @listener.run }
    sleep 0.1
    bot.update!(status: :starting)
    sleep 0.3

    @wnd.emit_event(npub, group_id, {
      "trigger" => "NewMessage",
      "message" => { "content" => "hello there", "author" => "someone" }
    })
    sleep 0.3

    @listener.shutdown
    @wnd.disconnect_all
    listener_thread.join(2)

    # Should log both incoming and outgoing
    assert_equal 1, bot.message_logs.incoming.count
    assert_equal 1, bot.message_logs.outgoing.count
    assert_equal "Hello back!", bot.message_logs.outgoing.first.content
  end

  # -- Hot reload of commands/triggers --

  test "picks up commands added after stream starts" do
    npub = SecureRandom.hex(32)
    group_id = "hotreload1"
    bot = Bot.create!(name: "HotBot", npub: npub, status: :stopped)
    @wnd.add_group(npub, group_id)

    listener_thread = Thread.new { @listener.run }
    sleep 0.1
    bot.update!(status: :starting)
    sleep 0.3

    # Add a command AFTER the stream is already running
    bot.commands.create!(name: "Late", pattern: "/late", response_text: "I was added late!", enabled: true)

    @wnd.emit_event(npub, group_id, {
      "trigger" => "NewMessage",
      "message" => { "content" => "/late", "author" => "someone" }
    })
    sleep 0.3

    @listener.shutdown
    @wnd.disconnect_all
    listener_thread.join(2)

    send_calls = @wnd.calls_for(:send_message)
    assert_equal 1, send_calls.size
    _, args = send_calls.first
    assert_equal "I was added late!", args[:message]
  end

  test "does not double-reply when bot's own message echoes back on stream" do
    npub = SecureRandom.hex(32)
    group_id = "echoback1"
    bot = Bot.create!(name: "EchoBackBot", npub: npub, status: :stopped)
    bot.commands.create!(name: "Ping", pattern: "/ping", response_text: "pong!", enabled: true)
    @wnd.add_group(npub, group_id)

    # Make send_message echo the bot's reply back onto the stream,
    # simulating real wnd behavior where sent messages appear on the subscription
    @wnd.define_singleton_method(:send_message_with_echo) do |account:, group_id:, message:|
      send_message(account: account, group_id: group_id, message: message)
      emit_event(account, group_id, {
        "trigger" => "NewMessage",
        "message" => { "content" => message, "author" => account }
      })
    end
    original_send = @wnd.method(:send_message)
    @wnd.define_singleton_method(:send_message) do |account:, group_id:, message:|
      @calls << [ :send_message, { account: account, group_id: group_id, message: message } ]
      emit_event(account, group_id, {
        "trigger" => "NewMessage",
        "message" => { "content" => message, "author" => account }
      })
    end

    listener_thread = Thread.new { @listener.run }
    sleep 0.1
    bot.update!(status: :starting)
    sleep 0.3

    @wnd.emit_event(npub, group_id, {
      "trigger" => "NewMessage",
      "message" => { "content" => "/ping", "author" => "otherpubkey123" }
    })
    sleep 0.5

    @listener.shutdown
    @wnd.disconnect_all
    listener_thread.join(2)

    send_calls = @wnd.calls_for(:send_message)
    assert_equal 1, send_calls.size, "Expected exactly 1 reply but got #{send_calls.size}: #{send_calls.map { |_, a| a[:message] }}"
  end

  test "does not create duplicate stream subscriptions for the same group" do
    npub = SecureRandom.hex(32)
    group_id = "dupstream1"
    bot = Bot.create!(name: "DupBot", npub: npub, status: :stopped)
    @wnd.add_group(npub, group_id)

    listener_thread = Thread.new { @listener.run }
    sleep 0.1
    bot.update!(status: :starting)
    # Wait long enough for multiple sync cycles (sync_interval is 0.05s in tests)
    sleep 0.5

    @listener.shutdown
    @wnd.disconnect_all
    listener_thread.join(2)

    subscribe_calls = @wnd.calls_for(:messages_subscribe)
    assert_equal 1, subscribe_calls.size,
      "Expected 1 subscription but got #{subscribe_calls.size} — duplicate streams detected"
  end

  test "logs incoming message even when no response is generated" do
    npub = SecureRandom.hex(32)
    group_id = "lognoresponse"
    bot = Bot.create!(name: "QuietBot", npub: npub, status: :stopped)
    @wnd.add_group(npub, group_id)

    listener_thread = Thread.new { @listener.run }
    sleep 0.1
    bot.update!(status: :starting)
    sleep 0.3

    @wnd.emit_event(npub, group_id, {
      "trigger" => "NewMessage",
      "message" => { "content" => "random stuff", "author" => "someone" }
    })
    sleep 0.3

    @listener.shutdown
    @wnd.disconnect_all
    listener_thread.join(2)

    assert_equal 1, bot.message_logs.incoming.count
    assert_equal 0, bot.message_logs.outgoing.count
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
