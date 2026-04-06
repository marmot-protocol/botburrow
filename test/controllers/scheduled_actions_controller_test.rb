require "test_helper"

class ScheduledActionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
    @bot = bots(:echo_bot)
    @action = scheduled_actions(:hourly_greeting)
  end

  # -- Authentication --

  test "unauthenticated user is redirected to login" do
    sign_out
    get new_bot_scheduled_action_path(@bot)
    assert_redirected_to new_session_path
  end

  # -- Index --

  test "index lists scheduled actions for the bot" do
    get bot_scheduled_actions_path(@bot)
    assert_response :success
    assert_select "table" do
      assert_select "tr", minimum: 2
    end
  end

  # -- New / Create --

  test "new scheduled action form renders" do
    get new_bot_scheduled_action_path(@bot)
    assert_response :success
    assert_select "form" do
      assert_select "input[name='scheduled_action[name]']"
      assert_select "input[name='scheduled_action[schedule]']"
      assert_select "textarea[name='scheduled_action[action_config]']"
      assert_select "input[name='scheduled_action[enabled]']"
    end
  end

  test "creating a scheduled action saves and redirects to bot" do
    assert_difference "ScheduledAction.count", 1 do
      post bot_scheduled_actions_path(@bot), params: {
        scheduled_action: {
          name: "Morning greeting",
          schedule: "every 1h",
          action_type: "send_message",
          action_config: '{"group_id": "g1", "message": "Hello!"}',
          enabled: "1"
        }
      }
    end

    action = ScheduledAction.last
    assert_equal "Morning greeting", action.name
    assert_equal "every 1h", action.schedule
    assert_equal "send_message", action.action_type
    assert action.enabled?
    assert_equal @bot, action.bot
    assert_not_nil action.next_run_at
    assert_redirected_to bot_path(@bot)
  end

  test "creating a scheduled action with invalid data re-renders form" do
    assert_no_difference "ScheduledAction.count" do
      post bot_scheduled_actions_path(@bot), params: {
        scheduled_action: { name: "", schedule: "", action_config: "" }
      }
    end

    assert_response :unprocessable_entity
  end

  # -- Edit / Update --

  test "edit form renders with current values" do
    get edit_bot_scheduled_action_path(@bot, @action)
    assert_response :success
    assert_select "input[name='scheduled_action[name]'][value='#{@action.name}']"
  end

  test "updating a scheduled action changes attributes" do
    patch bot_scheduled_action_path(@bot, @action), params: {
      scheduled_action: { name: "Updated greeting", schedule: "every 2h" }
    }

    assert_redirected_to bot_path(@bot)
    @action.reload
    assert_equal "Updated greeting", @action.name
    assert_equal "every 2h", @action.schedule
  end

  test "updating a scheduled action with invalid data re-renders form" do
    patch bot_scheduled_action_path(@bot, @action), params: {
      scheduled_action: { name: "" }
    }

    assert_response :unprocessable_entity
  end

  # -- Destroy --

  test "destroying a scheduled action deletes and redirects to bot" do
    assert_difference "ScheduledAction.count", -1 do
      delete bot_scheduled_action_path(@bot, @action)
    end

    assert_redirected_to bot_path(@bot)
  end
end
