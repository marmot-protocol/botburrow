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
    click_on "Schedules"
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
    click_on "Schedules"
    assert_text "Updated Action"
  end

  test "create a script scheduled action via the UI" do
    visit new_bot_scheduled_action_path(@bot)
    assert_selector "h1", text: "New scheduled action"

    fill_in "Name", with: "Scripted Greeting"
    fill_in "Schedule", with: "every 1h"
    select "Script", from: "Action type"
    # CodeMirror hides the script_body textarea; set values via JS.
    # Remove required from the hidden standard action_config textarea,
    # then set the script_body and action_config values in the script section.
    page.execute_script(<<~JS)
      var stdTextarea = document.querySelector("[data-response-type-target='standardField'] textarea");
      if (stdTextarea) stdTextarea.removeAttribute('required');
      document.querySelector("textarea[name='scheduled_action[script_body]']").value = '"Good morning!"';
    JS
    # The action_config textarea in the script section is not managed by CodeMirror,
    # so we can fill it directly via Capybara within the visible scriptField div.
    within "[data-response-type-target='scriptField']" do
      find("textarea[name='scheduled_action[action_config]']").fill_in with: '{"group_id": "abc123"}'
    end
    click_on "Create Scheduled action"

    assert_text "Scheduled action was successfully created"
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
    click_on "Schedules"
    assert_text "Scheduled Actions"
    assert_text "Hourly Check"
    assert_text "every 1h"
  end
end
