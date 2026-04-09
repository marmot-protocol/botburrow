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

  test "new trigger form renders with script editor" do
    get new_bot_trigger_path(@bot)
    assert_response :success
    assert_select "form" do
      assert_select "input[name='trigger[name]']"
      assert_select "select[name='trigger[condition_type]']"
      assert_select "input[name='trigger[condition_value]']"
      assert_select "textarea[name='trigger[script_body]']"
      assert_select "input[name='trigger[enabled]']"
    end
    # action_type and action_config should no longer exist
    assert_select "select[name='trigger[action_type]']", count: 0
    assert_select "textarea[name='trigger[action_config]']", count: 0
  end

  test "creating a trigger saves and redirects to bot" do
    assert_difference "Trigger.count", 1 do
      post bot_triggers_path(@bot), params: {
        trigger: {
          name: "New keyword trigger",
          condition_type: "keyword",
          condition_value: "test",
          script_body: '"Testing!"',
          enabled: "1"
        }
      }
    end

    trigger = Trigger.last
    assert_equal "New keyword trigger", trigger.name
    assert_equal "keyword", trigger.condition_type
    assert_equal "test", trigger.condition_value
    assert_equal '"Testing!"', trigger.script_body
    assert trigger.enabled?
    assert_equal @bot, trigger.bot
    assert_redirected_to bot_path(@bot, anchor: "triggers")
  end

  test "creating a trigger with invalid data re-renders form" do
    assert_no_difference "Trigger.count" do
      post bot_triggers_path(@bot), params: {
        trigger: { name: "", condition_type: "keyword", condition_value: "", script_body: "" }
      }
    end

    assert_response :unprocessable_entity
  end

  test "creating a trigger with missing script_body re-renders form" do
    assert_no_difference "Trigger.count" do
      post bot_triggers_path(@bot), params: {
        trigger: {
          name: "No body",
          condition_type: "keyword",
          condition_value: "test",
          script_body: "",
          enabled: "1"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "creating a trigger with invalid Ruby re-renders form" do
    assert_no_difference "Trigger.count" do
      post bot_triggers_path(@bot), params: {
        trigger: {
          name: "Bad script",
          condition_type: "keyword",
          condition_value: "test",
          script_body: "def foo(",
          enabled: "1"
        }
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

    assert_redirected_to bot_path(@bot, anchor: "triggers")
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

  # -- Toggle enabled --

  test "toggle_enabled flips enabled to disabled" do
    assert @trigger.enabled?
    patch toggle_enabled_bot_trigger_path(@bot, @trigger), as: :turbo_stream
    assert_response :success
    assert_not @trigger.reload.enabled?
  end

  test "toggle_enabled flips disabled to enabled" do
    @trigger.update!(enabled: false)
    patch toggle_enabled_bot_trigger_path(@bot, @trigger), as: :turbo_stream
    assert_response :success
    assert @trigger.reload.enabled?
  end

  # -- Destroy --

  test "destroying a trigger deletes and redirects to bot" do
    assert_difference "Trigger.count", -1 do
      delete bot_trigger_path(@bot, @trigger)
    end

    assert_redirected_to bot_path(@bot, anchor: "triggers")
  end
end
