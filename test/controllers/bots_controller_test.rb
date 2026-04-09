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
    ScheduledAction.delete_all
    Trigger.delete_all
    Command.delete_all
    Bot.delete_all
    get bots_path
    assert_response :success
    assert_select "p", /No bots yet/
  end

  test "index lists bots with status" do
    get bots_path
    assert_response :success
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
    assert_match @relay_bot.display_npub, response.body
    assert_select "td", "Ping"
    assert_select "td", "Help"
  end

  test "show displays QR code for bot npub" do
    get bot_path(@relay_bot)
    assert_response :success
    assert_select "svg"
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
      assert_select "a", "Bots"
      assert_select "button", "Log out"
    end
  end

  # -- Turbo Stream --

  test "index page includes turbo stream subscription" do
    get bots_path
    assert_select "turbo-cable-stream-source[channel='Turbo::StreamsChannel']"
  end

  # -- Groups --

  test "show displays groups fetched from wnd" do
    @wnd.stub_response(:groups_list, [
      {
        "group" => {
          "mls_group_id" => { "value" => { "vec" => [ 0xab, 0xcd, 0xef ] } },
          "name" => "Test Group",
          "state" => "active",
          "admin_pubkeys" => %w[pk1 pk2]
        },
        "membership" => {}
      }
    ])

    get bot_path(@relay_bot)
    assert_response :success
    assert_select "h3", "Groups"
    assert_select "td", "Test Group"
    assert_select "td", "active"
  end

  test "show handles empty groups" do
    @wnd.stub_response(:groups_list, [])

    get bot_path(@relay_bot)
    assert_response :success
    assert_select "p", /Not a member of any groups yet/
  end

  test "show handles wnd error when fetching groups" do
    @wnd.stub_error(:groups_list, "connection refused")

    get bot_path(@relay_bot)
    assert_response :success
    assert_select "p", /Not a member of any groups yet/
  end

  test "show resolves DM peer display name from user metadata" do
    peer_hex = "ab" * 32
    @wnd.stub_response(:groups_list, [
      {
        "group" => {
          "mls_group_id" => "string-id-456",
          "name" => "",
          "state" => "active"
        },
        "membership" => {
          "dm_peer_pubkey" => peer_hex
        }
      }
    ])
    @wnd.stub_response(:"users_show:#{peer_hex}", {
      "metadata" => { "display_name" => "Alice", "name" => "alice" }
    })

    get bot_path(@relay_bot)
    assert_response :success
    assert_select "td", "Alice"
  end

  test "show falls back to truncated npub when DM peer has no metadata" do
    peer_hex = "cd" * 32
    @wnd.stub_response(:groups_list, [
      {
        "group" => {
          "mls_group_id" => "string-id-789",
          "name" => "",
          "state" => "active"
        },
        "membership" => {
          "dm_peer_pubkey" => peer_hex
        }
      }
    ])
    @wnd.stub_response(:"users_show:#{peer_hex}", {})

    get bot_path(@relay_bot)
    assert_response :success
    npub = Wnd::Nostr.to_npub(peer_hex)
    assert_select "td", "#{npub.first(16)}..."
  end

  test "show displays unnamed group as (unnamed)" do
    @wnd.stub_response(:groups_list, [
      {
        "group" => {
          "mls_group_id" => "string-id-123",
          "name" => "",
          "state" => "active"
        },
        "membership" => {}
      }
    ])

    get bot_path(@relay_bot)
    assert_response :success
    assert_select "td", "(unnamed)"
  end

  # -- Invitations --

  test "show displays pending invitations for bot with auto_accept off" do
    @wnd.stub_response(:groups_list, [])
    @wnd.stub_response(:groups_invites, [
      {
        "group" => {
          "mls_group_id" => "invite-group-1",
          "name" => "Invited Group"
        }
      }
    ])

    get bot_path(@echo_bot) # echo_bot has auto_accept_invitations: false
    assert_response :success
    assert_select "h3", "Pending Invitations"
    assert_select "td", "Invited Group"
  end

  test "show does not fetch invitations when auto_accept is on" do
    @wnd.stub_response(:groups_list, [])

    get bot_path(@relay_bot) # relay_bot has auto_accept_invitations: true
    assert_response :success
    assert_select "h3", text: "Pending Invitations", count: 0
    assert_not @wnd.called?(:groups_invites)
  end

  # -- Accept/Decline --

  test "accept_invitation calls wnd and redirects" do
    post accept_invitation_bot_path(@echo_bot), params: { group_id: "abc123" }
    assert_redirected_to bot_path(@echo_bot)
    assert @wnd.called?(:groups_accept)
    args = @wnd.call_args(:groups_accept).first
    assert_equal @echo_bot.npub, args[:account]
    assert_equal "abc123", args[:group_id]
  end

  test "accept_invitation handles wnd error" do
    @wnd.stub_error(:groups_accept, "failed to accept")

    post accept_invitation_bot_path(@echo_bot), params: { group_id: "abc123" }
    assert_redirected_to bot_path(@echo_bot)
    follow_redirect!
    assert_select "[role='alert']", /Failed to accept/
  end

  test "decline_invitation calls wnd and redirects" do
    post decline_invitation_bot_path(@echo_bot), params: { group_id: "abc123" }
    assert_redirected_to bot_path(@echo_bot)
    assert @wnd.called?(:groups_decline)
    args = @wnd.call_args(:groups_decline).first
    assert_equal @echo_bot.npub, args[:account]
    assert_equal "abc123", args[:group_id]
  end

  test "decline_invitation handles wnd error" do
    @wnd.stub_error(:groups_decline, "failed to decline")

    post decline_invitation_bot_path(@echo_bot), params: { group_id: "abc123" }
    assert_redirected_to bot_path(@echo_bot)
    follow_redirect!
    assert_select "[role='alert']", /Failed to decline/
  end
end
