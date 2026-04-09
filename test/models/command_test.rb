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

  # -- Script validation --

  test "command with valid Ruby saves" do
    command = Command.new(
      bot: bots(:relay_bot), name: "Weather", pattern: "/weather",
      response_text: '"Hello from script"'
    )
    assert command.valid?
  end

  test "command with invalid Ruby fails validation" do
    command = Command.new(
      bot: bots(:relay_bot), name: "Bad", pattern: "/bad",
      response_text: "def foo("
    )
    assert_not command.valid?
    assert command.errors[:response_text].any? { |e| e.include?("syntax error") }
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
