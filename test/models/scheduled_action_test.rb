require "test_helper"

class ScheduledActionTest < ActiveSupport::TestCase
  # Slice 8: computes next_run_at from "every Xh" schedule
  test "compute_next_run sets next_run_at from hours schedule" do
    action = ScheduledAction.new(
      bot: bots(:relay_bot),
      name: "Test",
      schedule: "every 2h",
      action_type: :send_message,
      action_config: '{"group_id": "g1", "message": "hi"}',
      last_run_at: Time.current
    )
    action.compute_next_run
    assert_in_delta action.last_run_at + 2.hours, action.next_run_at, 1
  end

  test "compute_next_run sets next_run_at from minutes schedule" do
    action = ScheduledAction.new(
      bot: bots(:relay_bot),
      name: "Test",
      schedule: "every 30m",
      action_type: :send_message,
      action_config: '{"group_id": "g1", "message": "hi"}',
      last_run_at: Time.current
    )
    action.compute_next_run
    assert_in_delta action.last_run_at + 30.minutes, action.next_run_at, 1
  end

  test "compute_next_run sets next_run_at from days schedule" do
    action = ScheduledAction.new(
      bot: bots(:relay_bot),
      name: "Test",
      schedule: "every 1d",
      action_type: :send_message,
      action_config: '{"group_id": "g1", "message": "hi"}',
      last_run_at: Time.current
    )
    action.compute_next_run
    assert_in_delta action.last_run_at + 1.day, action.next_run_at, 1
  end

  test "compute_next_run uses Time.current when last_run_at is nil" do
    action = ScheduledAction.new(
      bot: bots(:relay_bot),
      name: "Test",
      schedule: "every 1h",
      action_type: :send_message,
      action_config: '{"group_id": "g1", "message": "hi"}',
      last_run_at: nil
    )
    action.compute_next_run
    assert_in_delta Time.current + 1.hour, action.next_run_at, 2
  end

  # Slice 9: due scope finds actions past their next_run_at
  test "due scope finds actions with next_run_at in the past" do
    due = ScheduledAction.enabled.due
    assert_includes due, scheduled_actions(:hourly_greeting)
    assert_not_includes due, scheduled_actions(:daily_report)
  end

  test "due scope excludes disabled actions when chained with enabled" do
    due = ScheduledAction.enabled.due
    assert_not_includes due, scheduled_actions(:disabled_action)
  end

  # Validations
  test "scheduled_action requires a name" do
    action = ScheduledAction.new(bot: bots(:relay_bot), name: nil, schedule: "every 1h",
                                 action_config: '{"group_id": "g1", "message": "hi"}')
    assert_not action.valid?
    assert_includes action.errors[:name], "can't be blank"
  end

  test "scheduled_action requires a schedule" do
    action = ScheduledAction.new(bot: bots(:relay_bot), name: "Test", schedule: nil,
                                 action_config: '{"group_id": "g1", "message": "hi"}')
    assert_not action.valid?
    assert_includes action.errors[:schedule], "can't be blank"
  end

  test "scheduled_action rejects invalid schedule format" do
    %w[random daily every5h every\ 5w cron\ 0\ *\ *].each do |bad_schedule|
      action = ScheduledAction.new(bot: bots(:relay_bot), name: "Test", schedule: bad_schedule,
                                   action_config: '{"group_id": "g1", "message": "hi"}')
      assert_not action.valid?, "Expected '#{bad_schedule}' to be invalid"
      assert_includes action.errors[:schedule], "must be like 'every 30m', 'every 1h', or 'every 1d'"
    end
  end

  test "scheduled_action accepts valid schedule formats" do
    %w[every\ 1m every\ 30m every\ 2h every\ 1d every\ 7d].each do |good_schedule|
      action = ScheduledAction.new(bot: bots(:relay_bot), name: "Test", schedule: good_schedule,
                                   action_config: '{"group_id": "g1", "message": "hi"}')
      assert action.valid?, "Expected '#{good_schedule}' to be valid, got: #{action.errors.full_messages}"
    end
  end

  test "scheduled_action requires action_config" do
    action = ScheduledAction.new(bot: bots(:relay_bot), name: "Test", schedule: "every 1h",
                                 action_config: nil)
    assert_not action.valid?
    assert_includes action.errors[:action_config], "can't be blank"
  end

  test "scheduled_action name is stripped of whitespace" do
    action = ScheduledAction.new(
      bot: bots(:relay_bot),
      name: "  Spaced  ",
      schedule: "every 1h",
      action_config: '{"group_id": "g1", "message": "hi"}'
    )
    assert_equal "Spaced", action.name
  end

  test "parsed_action_config returns parsed JSON" do
    action = scheduled_actions(:hourly_greeting)
    config = action.parsed_action_config
    assert_equal "testgroup1", config["group_id"]
    assert_equal "Good morning!", config["message"]
  end

  test "parsed_action_config returns empty hash for invalid JSON" do
    action = ScheduledAction.new(action_config: "not json")
    assert_equal({}, action.parsed_action_config)
  end

  # -- Script action type --

  test "scheduled action with script type saves" do
    action = ScheduledAction.new(
      bot: bots(:relay_bot), name: "Script action",
      schedule: "every 1h", action_type: :script,
      action_config: '{"group_id": "g1"}',
      script_body: '"Hello from script"'
    )
    assert action.valid?, "Expected valid, got: #{action.errors.full_messages}"
    assert action.script?
  end

  test "scheduled action with script type validates script_body presence" do
    action = ScheduledAction.new(
      bot: bots(:relay_bot), name: "Script action",
      schedule: "every 1h", action_type: :script,
      action_config: '{"group_id": "g1"}',
      script_body: nil
    )
    assert_not action.valid?
    assert_includes action.errors[:script_body], "can't be blank"
  end

  test "scheduled action with script type and invalid Ruby fails validation" do
    action = ScheduledAction.new(
      bot: bots(:relay_bot), name: "Script action",
      schedule: "every 1h", action_type: :script,
      action_config: '{"group_id": "g1"}',
      script_body: "def foo("
    )
    assert_not action.valid?
    assert action.errors[:script_body].any? { |e| e.include?("syntax error") }
  end

  test "scheduled action with script type does NOT require message in action_config" do
    action = ScheduledAction.new(
      bot: bots(:relay_bot), name: "Script action",
      schedule: "every 1h", action_type: :script,
      action_config: '{"group_id": "g1"}',
      script_body: '"Hello"'
    )
    assert action.valid?, "Expected valid, got: #{action.errors.full_messages}"
  end

  test "enabled scope filters to enabled actions" do
    enabled = ScheduledAction.enabled
    assert enabled.all?(&:enabled?)
    assert_not_includes enabled, scheduled_actions(:disabled_action)
  end
end

# == Schema Information
#
# Table name: scheduled_actions
#
#  id            :integer          not null, primary key
#  action_config :text             not null
#  action_type   :integer          default("send_message"), not null
#  enabled       :boolean          default(TRUE), not null
#  last_run_at   :datetime
#  name          :string           not null
#  next_run_at   :datetime
#  schedule      :string           not null
#  script_body   :text
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  bot_id        :integer          not null
#
# Indexes
#
#  index_scheduled_actions_on_bot_id  (bot_id)
#
# Foreign Keys
#
#  bot_id  (bot_id => bots.id)
#
