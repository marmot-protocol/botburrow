require "application_system_test_case"
require_relative "../support/wnd_stub"

class ScheduledActionsTest < ApplicationSystemTestCase
  setup do
    @wnd_stub = WndStubFactory.new
    BotsController.wnd_client_class = @wnd_stub
    sign_in
    @bot = bots(:relay_bot)
  end

  teardown do
    BotsController.wnd_client_class = Wnd::Client
  end

  test "create a scheduled action" do
    visit new_bot_scheduled_action_path(@bot)
    assert_selector "h1", text: "New scheduled action"

    fill_in "Name", with: "Morning greeting"
    fill_in "Schedule", with: "every 1h"
    find("textarea[name*='action_config']").fill_in with: '{"group_id": "abc123", "message": "Good morning!"}'
    click_on "Create Scheduled action"

    assert_text "Scheduled action was successfully created"
    assert_text "Morning greeting"
  end

  test "edit a scheduled action" do
    action = @bot.scheduled_actions.create!(
      name: "Old Action",
      schedule: "every 1h",
      action_type: :send_message,
      action_config: '{"group_id": "abc", "message": "hi"}',
      enabled: true
    )

    visit edit_bot_scheduled_action_path(@bot, action)
    fill_in "Name", with: "Updated Action"
    fill_in "Schedule", with: "every 30m"
    click_on "Update Scheduled action"

    assert_text "Scheduled action was successfully updated"
    assert_text "Updated Action"
  end

  test "scheduled actions appear on bot show page" do
    @bot.scheduled_actions.create!(
      name: "Hourly Check",
      schedule: "every 1h",
      action_type: :send_message,
      action_config: '{"group_id": "abc", "message": "check"}',
      enabled: true
    )

    visit bot_path(@bot)
    assert_text "Scheduled Actions"
    assert_text "Hourly Check"
    assert_text "every 1h"
  end
end
