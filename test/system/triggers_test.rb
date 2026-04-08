require "application_system_test_case"
require_relative "../support/wnd_stub"

class TriggersTest < ApplicationSystemTestCase
  setup do
    @wnd_stub = WndStubFactory.new
    BotsController.wnd_client_class = @wnd_stub
    sign_in
    @bot = bots(:relay_bot)
  end

  teardown do
    BotsController.wnd_client_class = Wnd::Client
  end

  test "create a trigger" do
    visit new_bot_trigger_path(@bot)
    assert_selector "h1", text: "New trigger"

    fill_in "Name", with: "Welcome"
    select "Message received", from: "Event type"
    select "Keyword", from: "Condition type"
    fill_in "Condition value", with: "hello"
    select "Reply", from: "Action type"
    fill_in "Action config (JSON)", with: '{"response_text": "Welcome!"}'
    click_on "Create Trigger"

    assert_text "Trigger was successfully created"
    click_on "Triggers"
    assert_text "Welcome"
  end

  test "edit a trigger" do
    trigger = @bot.triggers.create!(
      name: "Old Trigger",
      event_type: :message_received,
      condition_type: :keyword,
      condition_value: "test",
      action_type: :reply,
      action_config: '{"response_text": "old"}',
      enabled: true
    )

    visit edit_bot_trigger_path(@bot, trigger)
    assert_selector "h1", text: "Edit trigger"

    fill_in "Name", with: "Updated Trigger"
    find("input[type='submit']").click

    assert_text "Trigger was successfully updated"
  end

  test "create a script trigger via the UI" do
    visit new_bot_trigger_path(@bot)
    assert_selector "h1", text: "New trigger"

    fill_in "Name", with: "Script Trigger"
    select "Message received", from: "Event type"
    select "Keyword", from: "Condition type"
    fill_in "Condition value", with: "flip"
    select "Script", from: "Action type"
    # CodeMirror hides the textarea; set value directly for form submission
    page.execute_script("document.querySelector(\"textarea[name='trigger[script_body]']\").value = \"%w[Heads Tails].sample\"")
    click_on "Create Trigger"

    assert_text "Trigger was successfully created"
  end

  test "triggers appear on bot show page" do
    @bot.triggers.create!(
      name: "Greeter",
      event_type: :message_received,
      condition_type: :keyword,
      condition_value: "hi",
      action_type: :reply,
      action_config: '{"response_text": "Hello!"}',
      enabled: true
    )

    visit bot_path(@bot)
    click_on "Triggers"
    assert_text "Greeter"
    assert_text "Keyword"
  end
end
