require "application_system_test_case"
require_relative "../support/wnd_stub"

class ScheduledActionsTest < ApplicationSystemTestCase
  setup do
    @wnd_stub = WndStubFactory.new
    BotsController.wnd_client_class = @wnd_stub
    ScheduledActionsController.wnd_client_class = @wnd_stub
    sign_in
    @bot = bots(:relay_bot)
  end

  teardown do
    BotsController.wnd_client_class = Wnd::Client
    ScheduledActionsController.wnd_client_class = Wnd::Client
  end

  test "create a scheduled action with group checkboxes" do
    @wnd_stub.stub_response(:groups_list, [
      { "group" => { "mls_group_id" => { "value" => { "vec" => [1, 2, 3] } }, "name" => "Test Group", "state" => "active", "admin_pubkeys" => [] },
        "membership" => {} }
    ])

    visit new_bot_scheduled_action_path(@bot)
    assert_selector "h1", text: "New scheduled action"

    fill_in "Name", with: "Morning greeting"
    fill_in "Schedule (cron)", with: "0 * * * *"
    check "Test Group"
    page.execute_script("document.querySelector(\"textarea[name='scheduled_action[script_body]']\").value = '\"Good morning!\"'")
    click_on "Create Scheduled action"

    assert_text "Scheduled action was successfully created"
    click_on "Schedules"
    assert_text "Morning greeting"
  end

  test "edit a scheduled action" do
    action = @bot.scheduled_actions.create!(
      name: "Old Action", schedule: "0 * * * *",
      group_ids: ["abc"], script_body: '"hi"', enabled: true
    )

    visit edit_bot_scheduled_action_path(@bot, action)
    fill_in "Name", with: "Updated Action"
    fill_in "Schedule (cron)", with: "*/30 * * * *"
    click_on "Update Scheduled action"

    assert_text "Scheduled action was successfully updated"
    click_on "Schedules"
    assert_text "Updated Action"
  end

  test "scheduled actions appear on bot show page" do
    @bot.scheduled_actions.create!(
      name: "Hourly Check", schedule: "0 * * * *",
      group_ids: ["abc"], script_body: '"check"', enabled: true
    )

    visit bot_path(@bot)
    click_on "Schedules"
    assert_text "Scheduled Actions"
    assert_text "Hourly Check"
    assert_text "0 * * * *"
  end
end
