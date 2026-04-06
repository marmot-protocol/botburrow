require "test_helper"

class TriggersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
    @bot = bots(:relay_bot)
    @trigger = triggers(:keyword_trigger)
  end

  # -- Authentication --

  test "unauthenticated user is redirected to login" do
    sign_out
    get new_bot_trigger_path(@bot)
    assert_redirected_to new_session_path
  end

  # -- Index --

  test "index lists triggers for the bot" do
    get bot_triggers_path(@bot)
    assert_response :success
    assert_select "table" do
      assert_select "tr", minimum: 2
    end
  end

  # -- New / Create --

  test "new trigger form renders" do
    get new_bot_trigger_path(@bot)
    assert_response :success
    assert_select "form" do
      assert_select "input[name='trigger[name]']"
      assert_select "select[name='trigger[event_type]']"
      assert_select "select[name='trigger[condition_type]']"
      assert_select "input[name='trigger[condition_value]']"
      assert_select "select[name='trigger[action_type]']"
      assert_select "textarea[name='trigger[action_config]']"
      assert_select "input[name='trigger[enabled]']"
    end
  end

  test "creating a trigger saves and redirects to bot" do
    assert_difference "Trigger.count", 1 do
      post bot_triggers_path(@bot), params: {
        trigger: {
          name: "New keyword trigger",
          event_type: "message_received",
          condition_type: "keyword",
          condition_value: "test",
          action_type: "reply",
          action_config: '{"response_text": "Testing!"}',
          enabled: "1"
        }
      }
    end

    trigger = Trigger.last
    assert_equal "New keyword trigger", trigger.name
    assert_equal "keyword", trigger.condition_type
    assert_equal "test", trigger.condition_value
    assert_equal "reply", trigger.action_type
    assert trigger.enabled?
    assert_equal @bot, trigger.bot
    assert_redirected_to bot_path(@bot)
  end

  test "creating a trigger with invalid data re-renders form" do
    assert_no_difference "Trigger.count" do
      post bot_triggers_path(@bot), params: {
        trigger: { name: "", condition_type: "keyword", condition_value: "" }
      }
    end

    assert_response :unprocessable_entity
  end

  # -- Edit / Update --

  test "edit form renders with current values" do
    get edit_bot_trigger_path(@bot, @trigger)
    assert_response :success
    assert_select "input[name='trigger[name]'][value='#{@trigger.name}']"
  end

  test "updating a trigger changes attributes" do
    patch bot_trigger_path(@bot, @trigger), params: {
      trigger: { name: "Updated trigger", condition_value: "updated" }
    }

    assert_redirected_to bot_path(@bot)
    @trigger.reload
    assert_equal "Updated trigger", @trigger.name
    assert_equal "updated", @trigger.condition_value
  end

  test "updating a trigger with invalid data re-renders form" do
    patch bot_trigger_path(@bot, @trigger), params: {
      trigger: { name: "" }
    }

    assert_response :unprocessable_entity
  end

  # -- Destroy --

  test "destroying a trigger deletes and redirects to bot" do
    assert_difference "Trigger.count", -1 do
      delete bot_trigger_path(@bot, @trigger)
    end

    assert_redirected_to bot_path(@bot)
  end
end
