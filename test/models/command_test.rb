require "test_helper"

class CommandTest < ActiveSupport::TestCase
  test "command requires a name" do
    command = Command.new(bot: bots(:relay_bot), name: "Test", pattern: "/test", response_text: "testing")
    assert command.valid?

    command.name = nil
    assert_not command.valid?
    assert_includes command.errors[:name], "can't be blank"
  end

  test "command requires a pattern" do
    command = Command.new(bot: bots(:relay_bot), name: "Test", response_text: "testing")
    assert_not command.valid?
    assert_includes command.errors[:pattern], "can't be blank"
  end

  test "command requires response_text" do
    command = Command.new(bot: bots(:relay_bot), name: "Test", pattern: "/test")
    assert_not command.valid?
    assert_includes command.errors[:response_text], "can't be blank"
  end

  test "command pattern is unique per bot" do
    existing = commands(:ping)
    duplicate = Command.new(
      bot: existing.bot,
      name: "Another Ping",
      pattern: existing.pattern,
      response_text: "duplicate pong"
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:pattern], "has already been taken"
  end

  test "same pattern is allowed on different bots" do
    command = Command.new(
      bot: bots(:echo_bot),
      name: "Echo Ping",
      pattern: commands(:ping).pattern,
      response_text: "echo pong"
    )
    assert command.valid?
  end

  test "prefix matching matches message starting with pattern" do
    command = commands(:ping)
    assert command.matches?("/ping")
    assert command.matches?("/ping extra args")
    assert_not command.matches?("/pong")
  end

  test "prefix matching is case-insensitive" do
    command = commands(:ping)
    assert command.matches?("/PING")
    assert command.matches?("/Ping something")
  end

  test "enabled scope filters to enabled commands" do
    bot = bots(:relay_bot)
    enabled = bot.commands.enabled
    assert enabled.all?(&:enabled?)
    assert_not_includes enabled, commands(:disabled_command)
  end

  test "command name is stripped of whitespace" do
    command = Command.new(
      bot: bots(:relay_bot),
      name: "  Spaced  ",
      pattern: "/spaced",
      response_text: "trimmed"
    )
    assert_equal "Spaced", command.name
  end

  test "command pattern is stripped of whitespace" do
    command = Command.new(
      bot: bots(:relay_bot),
      name: "Trimmed",
      pattern: "  /trimmed  ",
      response_text: "trimmed"
    )
    assert_equal "/trimmed", command.pattern
  end

  # -- Argument extraction --

  test "extract_args returns text after the pattern for prefix match" do
    command = commands(:ping)
    assert_equal "30m take a break", command.extract_args("/ping 30m take a break")
  end

  test "extract_args returns empty string when no args" do
    command = commands(:ping)
    assert_equal "", command.extract_args("/ping")
  end

  test "extract_args returns nil when message does not match" do
    command = commands(:ping)
    assert_nil command.extract_args("/pong something")
  end

  test "extract_args is case-insensitive" do
    command = commands(:ping)
    assert_equal "world", command.extract_args("/PING world")
  end

  # -- Response types --

  test "command defaults to static response_type" do
    command = Command.new(bot: bots(:relay_bot), name: "T", pattern: "/t", response_text: "test")
    assert_equal "static", command.response_type
  end

  test "command supports template response_type" do
    command = Command.new(bot: bots(:relay_bot), name: "T", pattern: "/t", response_text: "test", response_type: :template)
    assert command.template?
  end

  test "command supports webhook response_type" do
    command = Command.new(bot: bots(:relay_bot), name: "T", pattern: "/t", response_text: "http://example.com/hook", response_type: :webhook)
    assert command.webhook?
  end

  # -- Template rendering --

  test "render_response returns response_text for static type" do
    command = commands(:ping)
    assert_equal "pong!", command.render_response({})
  end

  test "render_response interpolates template variables" do
    command = Command.new(
      bot: bots(:relay_bot),
      name: "Greet",
      pattern: "/greet",
      response_text: "Hello {{author}}, you said: {{args}}",
      response_type: :template
    )
    result = command.render_response(author: "alice", args: "world")
    assert_equal "Hello alice, you said: world", result
  end

  test "render_response interpolates bot_name and timestamp" do
    command = Command.new(
      bot: bots(:relay_bot),
      name: "Info",
      pattern: "/info",
      response_text: "Bot: {{bot_name}} at {{timestamp}}",
      response_type: :template
    )
    now = "2026-04-03T12:00:00Z"
    result = command.render_response(bot_name: "RelayBot", timestamp: now)
    assert_equal "Bot: RelayBot at 2026-04-03T12:00:00Z", result
  end

  test "render_response leaves unknown variables as-is" do
    command = Command.new(
      bot: bots(:relay_bot),
      name: "T",
      pattern: "/t",
      response_text: "Hello {{unknown}}",
      response_type: :template
    )
    assert_equal "Hello {{unknown}}", command.render_response({})
  end
end

# == Schema Information
#
# Table name: commands
#
#  id            :integer          not null, primary key
#  enabled       :boolean          default(TRUE), not null
#  name          :string           not null
#  pattern       :string           not null
#  response_text :text             not null
#  response_type :integer          default("static"), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  bot_id        :integer          not null
#
# Indexes
#
#  index_commands_on_bot_id              (bot_id)
#  index_commands_on_bot_id_and_pattern  (bot_id,pattern) UNIQUE
#
# Foreign Keys
#
#  bot_id  (bot_id => bots.id)
#
