require "test_helper"

class CommandsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
    @bot = bots(:relay_bot)
    @command = commands(:ping)
  end

  # -- Authentication --

  test "unauthenticated user is redirected to login" do
    sign_out
    get new_bot_command_path(@bot)
    assert_redirected_to new_session_path
  end

  # -- New / Create --

  test "new command form renders" do
    get new_bot_command_path(@bot)
    assert_response :success
    assert_select "form" do
      assert_select "input[name='command[name]']"
      assert_select "input[name='command[pattern]']"
      assert_select "textarea[name='command[response_text]']"
      assert_select "input[name='command[enabled]']"
    end
  end

  test "creating a command saves and redirects to bot" do
    assert_difference "Command.count", 1 do
      post bot_commands_path(@bot), params: {
        command: { name: "Status", pattern: "/status", response_text: "All systems go", enabled: "1" }
      }
    end

    command = Command.last
    assert_equal "Status", command.name
    assert_equal "/status", command.pattern
    assert_equal "All systems go", command.response_text
    assert command.enabled?
    assert_equal @bot, command.bot
    assert_redirected_to bot_path(@bot)
  end

  test "creating a command with invalid data re-renders form" do
    assert_no_difference "Command.count" do
      post bot_commands_path(@bot), params: {
        command: { name: "", pattern: "", response_text: "" }
      }
    end

    assert_response :unprocessable_entity
  end

  test "creating a command with duplicate pattern shows error" do
    assert_no_difference "Command.count" do
      post bot_commands_path(@bot), params: {
        command: { name: "Another Ping", pattern: "/ping", response_text: "duplicate!" }
      }
    end

    assert_response :unprocessable_entity
  end

  # -- Edit / Update --

  test "edit form renders with current values" do
    get edit_bot_command_path(@bot, @command)
    assert_response :success
    assert_select "input[name='command[name]'][value='#{@command.name}']"
  end

  test "updating a command changes attributes" do
    patch bot_command_path(@bot, @command), params: {
      command: { name: "Updated Ping", response_text: "updated pong!" }
    }

    assert_redirected_to bot_path(@bot)
    @command.reload
    assert_equal "Updated Ping", @command.name
    assert_equal "updated pong!", @command.response_text
  end

  test "updating a command with invalid data re-renders form" do
    patch bot_command_path(@bot, @command), params: {
      command: { name: "" }
    }

    assert_response :unprocessable_entity
  end

  # -- Destroy --

  test "destroying a command deletes and redirects to bot" do
    assert_difference "Command.count", -1 do
      delete bot_command_path(@bot, @command)
    end

    assert_redirected_to bot_path(@bot)
  end
end
