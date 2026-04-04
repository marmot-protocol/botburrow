require "test_helper"

class BotsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
    @wnd = WndStubFactory.new
    BotsController.wnd_client_class = @wnd
    @relay_bot = bots(:relay_bot)
    @echo_bot = bots(:echo_bot)
  end

  teardown do
    BotsController.wnd_client_class = Wnd::Client
  end

  # -- Authentication --

  test "unauthenticated user is redirected to login" do
    sign_out
    get bots_path
    assert_redirected_to new_session_path
  end

  # -- Index --

  test "index renders empty state when no bots" do
    Command.delete_all
    Bot.delete_all
    get bots_path
    assert_response :success
    assert_select "p", "No bots yet."
  end

  test "index lists bots with status" do
    get bots_path
    assert_response :success
    assert_select "table" do
      assert_select "tr", minimum: 2
    end
    assert_select "a", "RelayBot"
    assert_select "a", "EchoBot"
  end

  # -- New / Create --

  test "new bot form renders" do
    get new_bot_path
    assert_response :success
    assert_select "form" do
      assert_select "input[name='bot[name]']"
      assert_select "input[name='bot[auto_accept_invitations]']"
    end
  end

  test "creating a bot calls wnd and saves record" do
    npub = "npub1newbot#{SecureRandom.hex(20)}"
    @wnd.stub_response(:create_identity, { "pubkey" => npub })

    assert_difference "Bot.count", 1 do
      post bots_path, params: { bot: { name: "TestBot", auto_accept_invitations: "1" } }
    end

    bot = Bot.last
    assert_equal "TestBot", bot.name
    assert_equal npub, bot.npub
    assert bot.auto_accept_invitations
    assert_redirected_to bot_path(bot)
    assert @wnd.called?(:create_identity)
    assert @wnd.called?(:keys_publish)
  end

  test "creating a bot handles wnd connection error" do
    @wnd.stub_error(:create_identity, "connection refused")

    assert_no_difference "Bot.count" do
      post bots_path, params: { bot: { name: "TestBot" } }
    end

    assert_response :unprocessable_entity
    assert_select "li", /connection refused/i
  end

  test "creating a bot with blank name shows validation errors" do
    assert_no_difference "Bot.count" do
      post bots_path, params: { bot: { name: "" } }
    end

    assert_response :unprocessable_entity
  end

  # -- Show --

  test "show displays bot details and commands" do
    get bot_path(@relay_bot)
    assert_response :success
    assert_select "h1", @relay_bot.name
    assert_select "code", @relay_bot.display_npub
    assert_select "table" do
      assert_select "td", "Ping"
      assert_select "td", "Help"
    end
  end

  # -- Edit / Update --

  test "edit form renders" do
    get edit_bot_path(@relay_bot)
    assert_response :success
    assert_select "input[name='bot[name]'][value='#{@relay_bot.name}']"
  end

  test "update changes bot attributes" do
    patch bot_path(@relay_bot), params: { bot: { name: "UpdatedBot", auto_accept_invitations: "0" } }
    assert_redirected_to bot_path(@relay_bot)

    @relay_bot.reload
    assert_equal "UpdatedBot", @relay_bot.name
    assert_not @relay_bot.auto_accept_invitations
  end

  test "update with invalid data re-renders form" do
    patch bot_path(@relay_bot), params: { bot: { name: "" } }
    assert_response :unprocessable_entity
  end

  # -- Delete --

  test "destroy sets status to stopping and deletes bot" do
    assert_difference "Bot.count", -1 do
      delete bot_path(@relay_bot)
    end

    assert_redirected_to bots_path
  end

  test "destroy succeeds even when wnd is unavailable" do
    @wnd.stub_error(:accounts_list, "connection refused")

    assert_difference "Bot.count", -1 do
      delete bot_path(@relay_bot)
    end

    assert_redirected_to bots_path
  end

  # -- Start / Stop --

  test "start transitions bot to starting" do
    post start_bot_path(@relay_bot)
    assert_redirected_to bot_path(@relay_bot)

    @relay_bot.reload
    assert @relay_bot.starting?
  end

  test "stop transitions bot to stopping" do
    post stop_bot_path(@echo_bot)
    assert_redirected_to bot_path(@echo_bot)

    @echo_bot.reload
    assert @echo_bot.stopping?
  end

  # -- Flash messages --

  test "creating a bot shows success notice" do
    npub = "npub1flash#{SecureRandom.hex(20)}"
    @wnd.stub_response(:create_identity, { "pubkey" => npub })

    post bots_path, params: { bot: { name: "FlashBot", auto_accept_invitations: "1" } }
    follow_redirect!
    assert_select "[role='status']", /successfully created/i
  end

  test "updating a bot shows success notice" do
    patch bot_path(@relay_bot), params: { bot: { name: "UpdatedBot" } }
    follow_redirect!
    assert_select "[role='status']", /successfully updated/i
  end

  test "deleting a bot shows success notice" do
    delete bot_path(@relay_bot)
    follow_redirect!
    assert_select "[role='status']", /successfully deleted/i
  end

  # -- Layout --

  test "layout includes navigation with logout button" do
    get bots_path
    assert_select "nav" do
      assert_select "a", "Botburrow"
      assert_select "button", "Log out"
    end
  end

  # -- Turbo Stream --

  test "index page includes turbo stream subscription" do
    get bots_path
    assert_select "turbo-cable-stream-source[channel='Turbo::StreamsChannel']"
  end
end
