require "test_helper"
require_relative "../support/wnd_stub"

class ExecuteScheduledActionsJobTest < ActiveSupport::TestCase
  setup do
    @bot = bots(:echo_bot) # status: running
    @action = scheduled_actions(:hourly_greeting)
  end

  test "executes due actions for running bots" do
    wnd_calls = []
    stub_wnd = build_stub_wnd(wnd_calls)

    ExecuteScheduledActionsJob.perform_now(wnd_class: stub_wnd)

    assert_equal 1, wnd_calls.size
    call = wnd_calls.first
    assert_equal @bot.npub, call[:account]
    assert_equal "testgroup1", call[:group_id]
    assert_equal "Good morning!", call[:message]
  end

  test "executes in multiple groups" do
    action = ScheduledAction.create!(
      bot: @bot, name: "Multi-group", schedule: "0 * * * *",
      group_ids: ["group_a", "group_b"], script_body: '"hello"'
    )
    action.update_columns(next_run_at: 1.hour.ago)

    wnd_calls = []
    stub_wnd = build_stub_wnd(wnd_calls)

    ExecuteScheduledActionsJob.perform_now(wnd_class: stub_wnd)

    multi_calls = wnd_calls.select { |c| c[:group_id].start_with?("group_") }
    assert_equal 2, multi_calls.size
    assert_equal ["group_a", "group_b"], multi_calls.map { |c| c[:group_id] }.sort
    assert multi_calls.all? { |c| c[:message] == "hello" }
  end

  test "updates last_run_at and next_run_at after execution" do
    stub_wnd = build_stub_wnd([])

    before_run = Time.current
    ExecuteScheduledActionsJob.perform_now(wnd_class: stub_wnd)

    @action.reload
    assert_not_nil @action.last_run_at
    assert @action.last_run_at >= before_run
    assert @action.next_run_at > Time.current
  end

  test "skips actions for stopped bots" do
    wnd_calls = []
    stub_wnd = build_stub_wnd(wnd_calls)

    scheduled_actions(:daily_report).update!(next_run_at: 1.hour.ago)

    ExecuteScheduledActionsJob.perform_now(wnd_class: stub_wnd)

    bot_npubs = wnd_calls.map { |c| c[:account] }
    assert_includes bot_npubs, @bot.npub
    assert_not_includes bot_npubs, bots(:relay_bot).npub
  end

  test "script returning nil does not send" do
    action = ScheduledAction.create!(
      bot: @bot, name: "Silent script", schedule: "0 * * * *",
      group_ids: ["silentgroup"], script_body: 'store["counter"] = 1; nil'
    )
    action.update_columns(next_run_at: 1.hour.ago)

    wnd_calls = []
    stub_wnd = build_stub_wnd(wnd_calls)

    ExecuteScheduledActionsJob.perform_now(wnd_class: stub_wnd)

    script_calls = wnd_calls.select { |c| c[:group_id] == "silentgroup" }
    assert_empty script_calls
  end

  test "scheduled script can access wnd" do
    action = ScheduledAction.create!(
      bot: @bot, name: "Wnd test", schedule: "0 * * * *",
      group_ids: ["wndgroup"], script_body: 'wnd.groups; nil'
    )
    action.update_columns(next_run_at: 1.hour.ago)

    wnd_calls = []
    stub_wnd = build_stub_wnd(wnd_calls)

    ExecuteScheduledActionsJob.perform_now(wnd_class: stub_wnd)

    errors = @bot.message_logs.where(direction: "error", group_id: "wndgroup")
    assert_empty errors, "Expected no script errors, got: #{errors.map(&:content)}"
  end

  test "skips disabled actions even if due" do
    stub_wnd = build_stub_wnd([])

    disabled = scheduled_actions(:disabled_action)
    assert disabled.next_run_at <= Time.current
    assert_not disabled.enabled?

    ExecuteScheduledActionsJob.perform_now(wnd_class: stub_wnd)

    disabled.reload
    assert_nil disabled.last_run_at
  end

  private

  def build_stub_wnd(calls)
    Class.new do
      define_method(:initialize) { |**_| }
      define_method(:send_message) { |**kwargs| calls << kwargs }
      define_method(:method_missing) { |name, **_| nil unless name == :send_message }
      define_method(:respond_to_missing?) { |_, _| true }
    end
  end
end
