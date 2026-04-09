require "test_helper"
require_relative "../support/wnd_stub"

class ScheduledActionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
    @bot = bots(:echo_bot)
    @action = scheduled_actions(:hourly_greeting)
    @wnd_stub = WndStubFactory.new
    @wnd_stub.stub_response(:groups_list, [])
    ScheduledActionsController.wnd_client_class = @wnd_stub
  end

  teardown do
    ScheduledActionsController.wnd_client_class = Wnd::Client
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

  test "new form renders with script editor" do
    get new_bot_scheduled_action_path(@bot)
    assert_response :success
    assert_select "form" do
      assert_select "input[name='scheduled_action[name]']"
      assert_select "input[name='scheduled_action[schedule]']"
      assert_select "textarea[name='scheduled_action[script_body]']"
      assert_select "input[name='scheduled_action[enabled]']"
    end
  end

  test "creating a scheduled action saves with multiple groups" do
    assert_difference "ScheduledAction.count", 1 do
      post bot_scheduled_actions_path(@bot), params: {
        scheduled_action: {
          name: "Morning greeting",
          schedule: "0 * * * *",
          group_ids: ["g1", "g2"],
          script_body: '"Hello!"',
          enabled: "1"
        }
      }
    end

    action = ScheduledAction.last
    assert_equal "Morning greeting", action.name
    assert_equal ["g1", "g2"], action.group_ids
    assert action.enabled?
    assert_not_nil action.next_run_at
    assert_redirected_to bot_path(@bot, anchor: "schedules")
  end

  test "creating with invalid data re-renders form" do
    assert_no_difference "ScheduledAction.count" do
      post bot_scheduled_actions_path(@bot), params: {
        scheduled_action: { name: "", schedule: "", group_ids: [""], script_body: "" }
      }
    end

    assert_response :unprocessable_entity
  end

  test "creating with invalid Ruby re-renders form" do
    assert_no_difference "ScheduledAction.count" do
      post bot_scheduled_actions_path(@bot), params: {
        scheduled_action: {
          name: "Bad script",
          schedule: "0 * * * *",
          group_ids: ["g1"],
          script_body: "def foo(",
          enabled: "1"
        }
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

  test "updating changes attributes" do
    patch bot_scheduled_action_path(@bot, @action), params: {
      scheduled_action: { name: "Updated greeting", schedule: "0 */2 * * *" }
    }

    assert_redirected_to bot_path(@bot, anchor: "schedules")
    @action.reload
    assert_equal "Updated greeting", @action.name
    assert_equal "0 */2 * * *", @action.schedule
  end

  test "updating with invalid data re-renders form" do
    patch bot_scheduled_action_path(@bot, @action), params: {
      scheduled_action: { name: "" }
    }

    assert_response :unprocessable_entity
  end

  # -- Toggle enabled --

  test "toggle_enabled flips enabled to disabled" do
    assert @action.enabled?
    patch toggle_enabled_bot_scheduled_action_path(@bot, @action), as: :turbo_stream
    assert_response :success
    assert_not @action.reload.enabled?
  end

  test "toggle_enabled flips disabled to enabled" do
    @action.update!(enabled: false)
    patch toggle_enabled_bot_scheduled_action_path(@bot, @action), as: :turbo_stream
    assert_response :success
    assert @action.reload.enabled?
  end

  # -- Destroy --

  test "destroying deletes and redirects to bot" do
    assert_difference "ScheduledAction.count", -1 do
      delete bot_scheduled_action_path(@bot, @action)
    end

    assert_redirected_to bot_path(@bot, anchor: "schedules")
  end
end
