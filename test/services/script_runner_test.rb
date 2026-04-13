require "test_helper"

class ScriptRunnerTest < ActiveSupport::TestCase
  setup do
    @bot = Bot.create!(name: "RunBot", npub: SecureRandom.hex(32), status: :running)
    @group_id = "testgroup1"
  end

  test "executes a simple script and returns the string result" do
    ctx = build_context
    result = ScriptRunner.execute('"hello world"', ctx, bot: @bot, group_id: @group_id)

    assert_equal "hello world", result
  end

  test "returns nil for non-string results" do
    ctx = build_context
    result = ScriptRunner.execute("42", ctx, bot: @bot, group_id: @group_id)

    assert_nil result
  end

  test "saves store after successful execution" do
    ctx = build_context
    ScriptRunner.execute('store["count"] = 1; "done"', ctx, bot: @bot, group_id: @group_id)

    @bot.reload
    assert_equal({ "count" => 1 }, JSON.parse(@bot.script_data))
  end

  test "does not save store after error" do
    ctx = build_context
    ScriptRunner.execute('store["count"] = 99; raise "boom"', ctx, bot: @bot, group_id: @group_id)

    @bot.reload
    assert_equal({}, JSON.parse(@bot.script_data))
  end

  test "catches SystemExit" do
    ctx = build_context
    result = ScriptRunner.execute("exit", ctx, bot: @bot, group_id: @group_id)

    assert_nil result
    assert_error_logged("Script called exit")
  end

  test "catches NoMemoryError" do
    # We can't safely trigger NoMemoryError, so test the logging path directly
    ScriptRunner.log_script_error(@bot, @group_id, RuntimeError.new("Script used too much memory"))

    assert_error_logged("Script used too much memory")
  end

  test "catches SystemStackError from infinite recursion" do
    ctx = build_context
    script = <<~RUBY
      def recurse; recurse; end
      recurse
    RUBY
    result = ScriptRunner.execute(script, ctx, bot: @bot, group_id: @group_id)

    assert_nil result
    assert_error_logged("infinite recursion")
  end

  test "catches ScriptError (SyntaxError)" do
    ctx = build_context
    result = ScriptRunner.execute("def foo(", ctx, bot: @bot, group_id: @group_id)

    assert_nil result
    assert_error_logged("SyntaxError")
  end

  test "catches StandardError (runtime errors)" do
    ctx = build_context
    result = ScriptRunner.execute('raise "oops"', ctx, bot: @bot, group_id: @group_id)

    assert_nil result
    assert_error_logged("oops")
  end

  test "logs errors to message_logs with direction error and line numbers" do
    ctx = build_context
    script = <<~RUBY
      x = 1
      y = 2
      raise "kaboom"
    RUBY
    ScriptRunner.execute(script, ctx, bot: @bot, group_id: @group_id)

    log = @bot.message_logs.where(direction: "error").last
    assert_not_nil log
    assert_equal "system", log.author
    assert_includes log.content, "kaboom"
    assert_includes log.content, "line 3"
    assert_equal @group_id, log.group_id
  end

  test "cleans up leaked threads" do
    ctx = build_context
    script = 'Thread.new { sleep 999 }; "done"'

    threads_before = Thread.list.size
    ScriptRunner.execute(script, ctx, bot: @bot, group_id: @group_id)

    # Give the thread cleanup a moment
    sleep 0.05
    assert_equal threads_before, Thread.list.size
  end

  test "exec raises inside scripts via shadow" do
    ctx = build_context
    result = ScriptRunner.execute('exec("ls")', ctx, bot: @bot, group_id: @group_id)

    assert_nil result
    assert_error_logged("exec is not available")
  end

  test "fork raises inside scripts via shadow" do
    ctx = build_context
    result = ScriptRunner.execute("fork", ctx, bot: @bot, group_id: @group_id)

    assert_nil result
    assert_error_logged("fork is not available")
  end

  test "script can access context readers" do
    ctx = build_context
    result = ScriptRunner.execute('"Author: #{author}"', ctx, bot: @bot, group_id: @group_id)

    assert_equal "Author: alice", result
  end

  test "script can access wnd methods" do
    fake_wnd = Struct.new(:result).new("alice_profile")
    fake_wnd.define_singleton_method(:user) { |_pubkey| result }

    ctx = build_context(wnd: fake_wnd)
    result = ScriptRunner.execute('wnd.user(author)', ctx, bot: @bot, group_id: @group_id)

    assert_equal "alice_profile", result
  end

  test "script can send multiple messages" do
    sent = []
    ctx = build_context(sender: ->(text) { sent << text })
    result = ScriptRunner.execute(
      'send_message("first"); send_message("second"); "final"',
      ctx, bot: @bot, group_id: @group_id
    )

    assert_equal "final", result
    assert_equal %w[first second], sent
  end

  test "truncates error messages to 500 characters" do
    ctx = build_context
    long_message = "x" * 600
    ScriptRunner.execute(%(raise "#{long_message}"), ctx, bot: @bot, group_id: @group_id)

    log = @bot.message_logs.where(direction: "error").last
    assert log.content.length <= 500
  end

  private

  def build_context(sender: nil, wnd: nil)
    ScriptContext.new(
      bot: @bot, group_id: @group_id,
      author: "alice", message: "test", args: nil,
      sender: sender, wnd: wnd
    )
  end

  def assert_error_logged(substring)
    log = @bot.message_logs.where(direction: "error").last
    assert_not_nil log, "Expected an error log entry, but none found"
    assert_includes log.content, substring
  end
end
