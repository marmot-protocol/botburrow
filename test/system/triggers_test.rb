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
    select "Keyword", from: "Condition type"
    fill_in "Condition value", with: "hello"
    # Script editor — set value directly (CodeMirror hides the textarea)
    page.execute_script("document.querySelector(\"textarea[name='trigger[script_body]']\").value = '\"Welcome!\"'")
    click_on "Create Trigger"

    assert_text "Trigger was successfully created"
    click_on "Triggers"
    assert_text "Welcome"
  end

  test "edit a trigger" do
    trigger = @bot.triggers.create!(
      name: "Old Trigger",
      condition_type: :keyword,
      condition_value: "test",
      script_body: '"old response"',
      enabled: true
    )

    visit edit_bot_trigger_path(@bot, trigger)
    assert_selector "h1", text: "Edit trigger"

    fill_in "Name", with: "Updated Trigger"
    find("input[type='submit']").click

    assert_text "Trigger was successfully updated"
  end

  test "triggers appear on bot show page" do
    @bot.triggers.create!(
      name: "Greeter",
      condition_type: :keyword,
      condition_value: "hi",
      script_body: '"Hello!"',
      enabled: true
    )

    visit bot_path(@bot)
    click_on "Triggers"
    assert_text "Greeter"
    assert_text "Keyword"
  end
end
