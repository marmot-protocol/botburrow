require "test_helper"

class ScheduledActionTest < ActiveSupport::TestCase
  test "compute_next_run sets a future time based on cron" do
    action = ScheduledAction.new(
      bot: bots(:relay_bot), name: "Test", schedule: "0 * * * *",
      group_ids: ["g1"], script_body: '"hi"'
    )
    action.compute_next_run
    assert action.next_run_at > Time.current
  end

  test "compute_next_run with every-minute cron sets next_run within a minute" do
    action = ScheduledAction.new(
      bot: bots(:relay_bot), name: "Test", schedule: "* * * * *",
      group_ids: ["g1"], script_body: '"hi"'
    )
    action.compute_next_run
    assert_in_delta Time.current + 1.minute, action.next_run_at, 60
  end

  test "compute_next_run with daily cron sets next_run within 24 hours" do
    action = ScheduledAction.new(
      bot: bots(:relay_bot), name: "Test", schedule: "0 9 * * *",
      group_ids: ["g1"], script_body: '"hi"'
    )
    action.compute_next_run
    assert action.next_run_at > Time.current
    assert action.next_run_at <= Time.current + 24.hours
  end

  test "due scope finds actions with next_run_at in the past" do
    due = ScheduledAction.enabled.due
    assert_includes due, scheduled_actions(:hourly_greeting)
    assert_not_includes due, scheduled_actions(:daily_report)
  end

  test "due scope excludes disabled actions when chained with enabled" do
    due = ScheduledAction.enabled.due
    assert_not_includes due, scheduled_actions(:disabled_action)
  end

  # -- Validations --

  test "requires a name" do
    action = ScheduledAction.new(bot: bots(:relay_bot), name: nil, schedule: "0 * * * *",
                                 group_ids: ["g1"], script_body: '"hi"')
    assert_not action.valid?
    assert_includes action.errors[:name], "can't be blank"
  end

  test "requires a schedule" do
    action = ScheduledAction.new(bot: bots(:relay_bot), name: "Test", schedule: nil,
                                 group_ids: ["g1"], script_body: '"hi"')
    assert_not action.valid?
    assert_includes action.errors[:schedule], "can't be blank"
  end

  test "rejects invalid cron expressions" do
    ["not a cron", "* * *", "60 * * * *", "random"].each do |bad|
      action = ScheduledAction.new(bot: bots(:relay_bot), name: "Test", schedule: bad,
                                   group_ids: ["g1"], script_body: '"hi"')
      assert_not action.valid?, "Expected '#{bad}' to be invalid"
      assert_includes action.errors[:schedule], "is not a valid cron expression"
    end
  end

  test "accepts valid cron expressions" do
    ["* * * * *", "*/30 * * * *", "0 9 * * *", "0 9 * * 1", "0 0 1 * *", "0 */2 * * *"].each do |good|
      action = ScheduledAction.new(bot: bots(:relay_bot), name: "Test", schedule: good,
                                   group_ids: ["g1"], script_body: '"hi"')
      assert action.valid?, "Expected '#{good}' to be valid, got: #{action.errors.full_messages}"
    end
  end

  test "requires group_ids" do
    action = ScheduledAction.new(bot: bots(:relay_bot), name: "Test", schedule: "0 * * * *",
                                 group_ids: [], script_body: '"hi"')
    assert_not action.valid?
    assert_includes action.errors[:group_ids], "can't be blank"
  end

  test "requires script_body" do
    action = ScheduledAction.new(bot: bots(:relay_bot), name: "Test", schedule: "0 * * * *",
                                 group_ids: ["g1"], script_body: nil)
    assert_not action.valid?
    assert_includes action.errors[:script_body], "can't be blank"
  end

  test "validates script_body syntax" do
    action = ScheduledAction.new(bot: bots(:relay_bot), name: "Test", schedule: "0 * * * *",
                                 group_ids: ["g1"], script_body: "def foo(")
    assert_not action.valid?
    assert action.errors[:script_body].any? { |e| e.include?("syntax error") }
  end

  test "stores multiple group_ids" do
    action = ScheduledAction.create!(
      bot: bots(:relay_bot), name: "Multi", schedule: "0 * * * *",
      group_ids: ["g1", "g2", "g3"], script_body: '"hi"'
    )
    action.reload
    assert_equal ["g1", "g2", "g3"], action.group_ids
  end

  test "name is stripped of whitespace" do
    action = ScheduledAction.new(
      bot: bots(:relay_bot), name: "  Spaced  ", schedule: "0 * * * *",
      group_ids: ["g1"], script_body: '"hi"'
    )
    assert_equal "Spaced", action.name
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
#  id          :integer          not null, primary key
#  enabled     :boolean          default(TRUE), not null
#  group_ids   :string
#  last_run_at :datetime
#  name        :string           not null
#  next_run_at :datetime
#  schedule    :string           not null
#  script_body :text
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  bot_id      :integer          not null
#
# Indexes
#
#  index_scheduled_actions_on_bot_id  (bot_id)
#
# Foreign Keys
#
#  bot_id  (bot_id => bots.id)
#
