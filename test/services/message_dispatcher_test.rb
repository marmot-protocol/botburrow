require "test_helper"

class MessageDispatcherTest < ActiveSupport::TestCase
  setup do
    @wnd_calls = []
    @wnd = stub_wnd(@wnd_calls)
    @bot = Bot.create!(name: "DispatchBot", npub: SecureRandom.hex(32), status: :running)
    @group_id = "testgroup1"
  end

  test "dispatches matching command response" do
    @bot.commands.create!(name: "Ping", pattern: "/ping", response_text: '"pong!"', enabled: true)

    dispatch(content: "/ping", author: "alice")

    assert_sent "pong!"
  end

  test "skips disabled commands" do
    @bot.commands.create!(name: "Ping", pattern: "/ping", response_text: '"pong!"', enabled: false)

    dispatch(content: "/ping", author: "alice")

    assert_nothing_sent
  end

  test "dispatches built-in /help listing enabled commands" do
    @bot.commands.create!(name: "Ping", pattern: "/ping", response_text: '"pong!"', enabled: true)
    @bot.commands.create!(name: "Secret", pattern: "/secret", response_text: '"hidden"', enabled: false)

    dispatch(content: "/help", author: "alice")

    response = last_sent_message
    assert_includes response, "/ping"
    assert_includes response, "Ping"
    assert_not_includes response, "Secret"
  end

  test "dispatches built-in /status with bot info" do
    @bot.commands.create!(name: "Ping", pattern: "/ping", response_text: '"pong!"', enabled: true)

    dispatch(content: "/status", author: "alice")

    response = last_sent_message
    assert_includes response, "DispatchBot"
    assert_includes response, "1"
  end

  test "trigger script sends reply when it returns a string" do
    @bot.triggers.create!(
      name: "Hello", condition_type: :keyword,
      condition_value: "hello", script_body: '"Hello back!"',
      position: 1, enabled: true
    )

    dispatch(content: "hello world", author: "alice")

    assert_sent "Hello back!"
  end

  test "trigger script returning nil sends nothing" do
    @bot.triggers.create!(
      name: "Silent", condition_type: :any,
      script_body: "nil", position: 1, enabled: true
    )

    dispatch(content: "anything", author: "alice")

    assert_nothing_sent
  end

  test "first matching trigger wins by position" do
    @bot.triggers.create!(
      name: "Catch-all", condition_type: :any,
      script_body: '"Catch-all"', position: 2, enabled: true
    )
    @bot.triggers.create!(
      name: "Hello", condition_type: :keyword,
      condition_value: "hello", script_body: '"Hello first!"',
      position: 1, enabled: true
    )

    dispatch(content: "hello there", author: "alice")

    assert_sent "Hello first!"
  end

  test "commands take priority over triggers" do
    @bot.commands.create!(name: "Ping", pattern: "/ping", response_text: '"pong!"', enabled: true)
    @bot.triggers.create!(
      name: "Catch-all", condition_type: :any,
      script_body: '"Caught!"', position: 1, enabled: true
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
    @bot.commands.create!(name: "Ping", pattern: "/ping", response_text: '"pong!"', enabled: true)

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

  # -- Script command tests --

  test "script command returns a string reply" do
    @bot.commands.create!(
      name: "Hello", pattern: "/hello",
      response_text: '"Hello from script!"',
      enabled: true
    )

    dispatch(content: "/hello", author: "alice")

    assert_sent "Hello from script!"
  end

  test "script command returning nil does not send a reply" do
    @bot.commands.create!(
      name: "Silent", pattern: "/silent",
      response_text: 'store["counter"] = 1; nil',
      enabled: true
    )

    dispatch(content: "/silent", author: "alice")

    assert_nothing_sent
  end

  test "script command with send_message sends multiple messages" do
    @bot.commands.create!(
      name: "Multi", pattern: "/multi",
      response_text: 'send_message("first"); send_message("second"); "third"',
      enabled: true
    )

    dispatch(content: "/multi", author: "alice")

    assert_equal 3, @wnd_calls.size
    assert_equal "first", @wnd_calls[0][:message]
    assert_equal "second", @wnd_calls[1][:message]
    assert_equal "third", @wnd_calls[2][:message]
  end

  test "trigger script can use send_message for multi-message flows" do
    @bot.triggers.create!(
      name: "Multi", condition_type: :keyword,
      condition_value: "multi", script_body: 'send_message("one"); "two"',
      position: 1, enabled: true
    )

    dispatch(content: "multi test", author: "alice")

    assert_equal 2, @wnd_calls.size
    assert_equal "one", @wnd_calls[0][:message]
    assert_equal "two", @wnd_calls[1][:message]
  end

  test "script command can access wnd.profile" do
    @bot.commands.create!(
      name: "Me", pattern: "/me",
      response_text: 'wnd.profile.to_s',
      enabled: true
    )

    dispatch(content: "/me", author: "alice")

    # wnd.profile calls profile_show on the stub, which returns nil.
    # The script converts nil to ""; script returns empty string → no reply sent.
    # The point is: no NoMethodError on `wnd` — it's wired up.
    assert_no_errors_logged
  end

  test "trigger script can access wnd.user" do
    @bot.triggers.create!(
      name: "Whois", condition_type: :keyword,
      condition_value: "whois", script_body: 'wnd.user(author).to_s',
      position: 1, enabled: true
    )

    dispatch(content: "whois", author: "alice")

    assert_no_errors_logged
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
      wnd.define_singleton_method(:method_missing) do |name, **_kwargs|
        nil unless name == :send_message
      end
      wnd.define_singleton_method(:respond_to_missing?) { |_, _| true }
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

  def assert_no_errors_logged
    errors = @bot.message_logs.where(direction: "error")
    assert_empty errors, "Expected no script errors, got: #{errors.map(&:content)}"
  end
end
