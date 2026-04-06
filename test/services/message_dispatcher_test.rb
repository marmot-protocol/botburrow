require "test_helper"
require "webmock/minitest"

class MessageDispatcherTest < ActiveSupport::TestCase
  setup do
    @wnd_calls = []
    @wnd = stub_wnd(@wnd_calls)
    @bot = Bot.create!(name: "DispatchBot", npub: SecureRandom.hex(32), status: :running)
    @group_id = "testgroup1"
  end

  test "dispatches matching command response" do
    @bot.commands.create!(name: "Ping", pattern: "/ping", response_text: "pong!", enabled: true)

    dispatch(content: "/ping", author: "alice")

    assert_sent "pong!"
  end

  test "skips disabled commands" do
    @bot.commands.create!(name: "Ping", pattern: "/ping", response_text: "pong!", enabled: false)

    dispatch(content: "/ping", author: "alice")

    assert_nothing_sent
  end

  test "dispatches template response with interpolation" do
    @bot.commands.create!(
      name: "Greet", pattern: "/greet",
      response_text: "Hello {{author}}, args: {{args}}",
      response_type: :template, enabled: true
    )

    dispatch(content: "/greet world", author: "alice")

    assert_sent "Hello alice, args: world"
  end

  test "dispatches built-in /help listing enabled commands" do
    @bot.commands.create!(name: "Ping", pattern: "/ping", response_text: "pong!", enabled: true)
    @bot.commands.create!(name: "Secret", pattern: "/secret", response_text: "hidden", enabled: false)

    dispatch(content: "/help", author: "alice")

    response = last_sent_message
    assert_includes response, "/ping"
    assert_includes response, "Ping"
    assert_not_includes response, "Secret"
  end

  test "dispatches built-in /status with bot info" do
    @bot.commands.create!(name: "Ping", pattern: "/ping", response_text: "pong!", enabled: true)

    dispatch(content: "/status", author: "alice")

    response = last_sent_message
    assert_includes response, "DispatchBot"
    assert_includes response, "1"
  end

  test "dispatches trigger reply when no command matches" do
    @bot.triggers.create!(
      name: "Hello", event_type: :message_received, condition_type: :keyword,
      condition_value: "hello", action_type: :reply,
      action_config: '{"response_text": "Hello back!"}', position: 1, enabled: true
    )

    dispatch(content: "hello world", author: "alice")

    assert_sent "Hello back!"
  end

  test "first matching trigger wins by position" do
    @bot.triggers.create!(
      name: "Catch-all", event_type: :message_received, condition_type: :any,
      action_type: :reply, action_config: '{"response_text": "Catch-all"}',
      position: 2, enabled: true
    )
    @bot.triggers.create!(
      name: "Hello", event_type: :message_received, condition_type: :keyword,
      condition_value: "hello", action_type: :reply,
      action_config: '{"response_text": "Hello first!"}', position: 1, enabled: true
    )

    dispatch(content: "hello there", author: "alice")

    assert_sent "Hello first!"
  end

  test "log_only trigger does not send a reply" do
    @bot.triggers.create!(
      name: "Logger", event_type: :message_received, condition_type: :any,
      action_type: :log_only, position: 1, enabled: true
    )

    dispatch(content: "anything", author: "alice")

    assert_nothing_sent
  end

  test "commands take priority over triggers" do
    @bot.commands.create!(name: "Ping", pattern: "/ping", response_text: "pong!", enabled: true)
    @bot.triggers.create!(
      name: "Catch-all", event_type: :message_received, condition_type: :any,
      action_type: :reply, action_config: '{"response_text": "Caught!"}',
      position: 1, enabled: true
    )

    dispatch(content: "/ping", author: "alice")

    assert_sent "pong!"
    assert_equal 1, @wnd_calls.size
  end

  test "logs incoming message" do
    dispatch(content: "hello", author: "alice")

    incoming = @bot.message_logs.incoming
    assert_equal 1, incoming.count
    assert_equal "hello", incoming.first.content
    assert_equal "alice", incoming.first.author
  end

  test "logs outgoing response" do
    @bot.commands.create!(name: "Ping", pattern: "/ping", response_text: "pong!", enabled: true)

    dispatch(content: "/ping", author: "alice")

    outgoing = @bot.message_logs.outgoing
    assert_equal 1, outgoing.count
    assert_equal "pong!", outgoing.first.content
  end

  test "logs incoming even when no response" do
    dispatch(content: "random stuff", author: "alice")

    assert_equal 1, @bot.message_logs.incoming.count
    assert_equal 0, @bot.message_logs.outgoing.count
  end

  test "webhook command dispatches to endpoint and sends response" do
    endpoint = @bot.webhook_endpoints.create!(name: "Hook", url: "https://example.com/hook", enabled: true)
    @bot.commands.create!(
      name: "Ask", pattern: "/ask", response_text: endpoint.url,
      response_type: :webhook, enabled: true
    )

    stub_request(:post, "https://example.com/hook")
      .to_return(status: 200, body: "Webhook says hello!")

    dispatch(content: "/ask something", author: "alice")

    assert_sent "Webhook says hello!"
    assert_equal 1, WebhookDelivery.count
  end

  private

  def dispatch(content:, author:)
    dispatcher = MessageDispatcher.new(@bot, @group_id, wnd_class: stub_wnd_class(@wnd, @wnd_calls))
    dispatcher.dispatch(content, author)
  end

  def stub_wnd(calls)
    Object.new.tap do |wnd|
      wnd.define_singleton_method(:send_message) do |**kwargs|
        calls << kwargs
      end
    end
  end

  def stub_wnd_class(instance, _calls)
    Class.new do
      define_method(:new) { |**_| instance }
    end.new
  end

  def assert_sent(message)
    assert_equal 1, @wnd_calls.size, "Expected exactly 1 sent message, got #{@wnd_calls.size}"
    assert_equal message, @wnd_calls.first[:message]
  end

  def assert_nothing_sent
    assert_empty @wnd_calls, "Expected no messages sent, got: #{@wnd_calls.map { _1[:message] }}"
  end

  def last_sent_message
    assert @wnd_calls.any?, "Expected at least one sent message"
    @wnd_calls.last[:message]
  end
end
