require "test_helper"

class TriggerTest < ActiveSupport::TestCase
  # Slice 1: keyword matching (case-insensitive, substring)
  test "keyword trigger matches case-insensitively as substring" do
    trigger = triggers(:keyword_trigger)
    assert trigger.matches?("hello")
    assert trigger.matches?("HELLO WORLD")
    assert trigger.matches?("say hello please")
    assert_not trigger.matches?("goodbye")
  end

  # Slice 2: regex matching
  test "regex trigger matches against regex pattern" do
    trigger = triggers(:regex_trigger)
    assert trigger.matches?("found bug #123")
    assert trigger.matches?("BUG123 is critical")
    assert trigger.matches?("bug#42")
    assert_not trigger.matches?("no bugs here")
  end

  # Slice 3: any condition matches everything
  test "any trigger matches any text" do
    trigger = triggers(:any_trigger)
    assert trigger.matches?("anything at all")
    assert trigger.matches?("")
    assert trigger.matches?("hello world")
  end

  test "catastrophic regex backtracking returns false instead of hanging" do
    trigger = Trigger.new(
      bot: bots(:relay_bot),
      name: "ReDoS",
      event_type: :message_received,
      condition_type: :regex,
      condition_value: "(a+)+$",
      action_type: :reply,
      action_config: '{"response_text": "nope"}'
    )
    # This input causes catastrophic backtracking on unprotected regex engines.
    # Should return false within a reasonable time, not hang.
    assert_not trigger.matches?("a" * 30 + "!")
  end

  test "trigger with invalid regex returns false instead of crashing" do
    trigger = Trigger.new(
      bot: bots(:relay_bot),
      name: "Bad regex",
      event_type: :message_received,
      condition_type: :regex,
      condition_value: "[invalid(",
      action_type: :reply,
      action_config: '{"response_text": "nope"}'
    )
    assert_not trigger.matches?("test")
  end

  # Validations
  test "trigger requires a name" do
    trigger = Trigger.new(bot: bots(:relay_bot), name: "Test", event_type: :message_received,
                          condition_type: :keyword, condition_value: "test", action_type: :reply)
    assert trigger.valid?

    trigger.name = nil
    assert_not trigger.valid?
    assert_includes trigger.errors[:name], "can't be blank"
  end

  test "trigger requires condition_value for keyword type" do
    trigger = Trigger.new(bot: bots(:relay_bot), name: "Test", event_type: :message_received,
                          condition_type: :keyword, condition_value: nil, action_type: :reply)
    assert_not trigger.valid?
    assert_includes trigger.errors[:condition_value], "can't be blank"
  end

  test "trigger does not require condition_value for any type" do
    trigger = Trigger.new(bot: bots(:relay_bot), name: "Test", event_type: :message_received,
                          condition_type: :any, condition_value: nil, action_type: :log_only)
    assert trigger.valid?
  end

  test "enabled scope filters to enabled triggers" do
    bot = bots(:relay_bot)
    enabled = bot.triggers.enabled
    assert enabled.all?(&:enabled?)
    assert_not_includes enabled, triggers(:disabled_trigger)
  end

  test "trigger name is stripped of whitespace" do
    trigger = Trigger.new(
      bot: bots(:relay_bot),
      name: "  Spaced  ",
      event_type: :message_received,
      condition_type: :keyword,
      condition_value: "test",
      action_type: :reply
    )
    assert_equal "Spaced", trigger.name
  end

  # -- Script action type --

  test "trigger with script action type and valid script_body saves" do
    trigger = Trigger.new(
      bot: bots(:relay_bot), name: "Script trigger",
      event_type: :message_received, condition_type: :keyword,
      condition_value: "test", action_type: :script,
      script_body: '"Hello from script"'
    )
    assert trigger.valid?
    assert trigger.script?
  end

  test "trigger with script action type and no script_body fails validation" do
    trigger = Trigger.new(
      bot: bots(:relay_bot), name: "Script trigger",
      event_type: :message_received, condition_type: :keyword,
      condition_value: "test", action_type: :script,
      script_body: nil
    )
    assert_not trigger.valid?
    assert_includes trigger.errors[:script_body], "can't be blank"
  end

  test "trigger with script action type and invalid Ruby fails validation" do
    trigger = Trigger.new(
      bot: bots(:relay_bot), name: "Script trigger",
      event_type: :message_received, condition_type: :keyword,
      condition_value: "test", action_type: :script,
      script_body: "def foo("
    )
    assert_not trigger.valid?
    assert trigger.errors[:script_body].any? { |e| e.include?("syntax error") }
  end

  test "parsed_action_config returns parsed JSON" do
    trigger = triggers(:keyword_trigger)
    config = trigger.parsed_action_config
    assert_equal "Welcome to the group!", config["response_text"]
  end

  test "parsed_action_config returns empty hash for nil" do
    trigger = Trigger.new(action_config: nil)
    assert_equal({}, trigger.parsed_action_config)
  end

  test "parsed_action_config returns empty hash for invalid JSON" do
    trigger = Trigger.new(action_config: "not json")
    assert_equal({}, trigger.parsed_action_config)
  end
end

# == Schema Information
#
# Table name: triggers
#
#  id              :integer          not null, primary key
#  action_config   :text
#  action_type     :integer          default("reply"), not null
#  condition_type  :integer          default("keyword"), not null
#  condition_value :string
#  enabled         :boolean          default(TRUE), not null
#  event_type      :integer          default("message_received"), not null
#  name            :string           not null
#  position        :integer
#  script_body     :text
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  bot_id          :integer          not null
#
# Indexes
#
#  index_triggers_on_bot_id  (bot_id)
#
# Foreign Keys
#
#  bot_id  (bot_id => bots.id)
#
