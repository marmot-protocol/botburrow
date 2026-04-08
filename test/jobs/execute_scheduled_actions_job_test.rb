require "test_helper"
require_relative "../support/wnd_stub"

class ExecuteScheduledActionsJobTest < ActiveSupport::TestCase
  setup do
    @bot = bots(:echo_bot) # status: running
    @action = scheduled_actions(:hourly_greeting)
  end

  # Slice 10: sends message for due actions
  test "executes due send_message actions for running bots" do
    assert @bot.running?
    assert @action.enabled?
    assert @action.next_run_at <= Time.current

    wnd_calls = []
    stub_wnd = Class.new do
      define_method(:initialize) { |**_| }
      define_method(:send_message) { |**kwargs| wnd_calls << kwargs }
    end

    ExecuteScheduledActionsJob.perform_now(wnd_class: stub_wnd)

    assert_equal 1, wnd_calls.size
    call = wnd_calls.first
    assert_equal @bot.npub, call[:account]
    assert_equal "testgroup1", call[:group_id]
    assert_equal "Good morning!", call[:message]
  end

  # Slice 11: updates last_run_at and next_run_at after execution
  test "updates last_run_at and next_run_at after execution" do
    stub_wnd = Class.new do
      define_method(:initialize) { |**_| }
      define_method(:send_message) { |**_| }
    end

    before_run = Time.current
    ExecuteScheduledActionsJob.perform_now(wnd_class: stub_wnd)

    @action.reload
    assert_not_nil @action.last_run_at
    assert @action.last_run_at >= before_run
    assert @action.next_run_at > @action.last_run_at
  end

  # Slice 12: skips actions for stopped bots
  test "skips actions for stopped bots" do
    stopped_action = scheduled_actions(:disabled_action)
    # disabled_action belongs to relay_bot which is stopped
    assert bots(:relay_bot).stopped?

    wnd_calls = []
    stub_wnd = Class.new do
      define_method(:initialize) { |**_| }
      define_method(:send_message) { |**kwargs| wnd_calls << kwargs }
    end

    # Make the daily_report due (it belongs to relay_bot which is stopped)
    scheduled_actions(:daily_report).update!(next_run_at: 1.hour.ago)

    ExecuteScheduledActionsJob.perform_now(wnd_class: stub_wnd)

    # Only hourly_greeting (echo_bot, running) should have fired
    # daily_report (relay_bot, stopped) should not
    bot_npubs = wnd_calls.map { |c| c[:account] }
    assert_includes bot_npubs, @bot.npub
    assert_not_includes bot_npubs, bots(:relay_bot).npub
  end

  # -- Script action type --

  test "script scheduled action executes and sends result" do
    action = ScheduledAction.create!(
      bot: @bot, name: "Script action",
      schedule: "every 1h", action_type: :script,
      action_config: '{"group_id": "scriptgroup1"}',
      script_body: '"Hello from scheduled script!"'
    )
    action.update_columns(next_run_at: 1.hour.ago)

    wnd_calls = []
    stub_wnd = Class.new do
      define_method(:initialize) { |**_| }
      define_method(:send_message) { |**kwargs| wnd_calls << kwargs }
    end

    ExecuteScheduledActionsJob.perform_now(wnd_class: stub_wnd)

    script_calls = wnd_calls.select { |c| c[:group_id] == "scriptgroup1" }
    assert_equal 1, script_calls.size
    assert_equal "Hello from scheduled script!", script_calls.first[:message]
    assert_equal @bot.npub, script_calls.first[:account]
  end

  test "script scheduled action returning nil does not send" do
    action = ScheduledAction.create!(
      bot: @bot, name: "Silent script",
      schedule: "every 1h", action_type: :script,
      action_config: '{"group_id": "scriptgroup2"}',
      script_body: 'store["counter"] = 1; nil'
    )
    action.update_columns(next_run_at: 1.hour.ago)

    wnd_calls = []
    stub_wnd = Class.new do
      define_method(:initialize) { |**_| }
      define_method(:send_message) { |**kwargs| wnd_calls << kwargs }
    end

    ExecuteScheduledActionsJob.perform_now(wnd_class: stub_wnd)

    script_calls = wnd_calls.select { |c| c[:group_id] == "scriptgroup2" }
    assert_empty script_calls
  end

  test "existing send_message action still works after script addition" do
    wnd_calls = []
    stub_wnd = Class.new do
      define_method(:initialize) { |**_| }
      define_method(:send_message) { |**kwargs| wnd_calls << kwargs }
    end

    ExecuteScheduledActionsJob.perform_now(wnd_class: stub_wnd)

    greeting_calls = wnd_calls.select { |c| c[:group_id] == "testgroup1" }
    assert_equal 1, greeting_calls.size
    assert_equal "Good morning!", greeting_calls.first[:message]
  end

  test "skips disabled actions even if due" do
    stub_wnd = Class.new do
      define_method(:initialize) { |**_| }
      define_method(:send_message) { |**_| }
    end

    # disabled_action is due but disabled
    disabled = scheduled_actions(:disabled_action)
    assert disabled.next_run_at <= Time.current
    assert_not disabled.enabled?

    ExecuteScheduledActionsJob.perform_now(wnd_class: stub_wnd)

    disabled.reload
    assert_nil disabled.last_run_at # Should not have been updated
  end
end
