require_relative "e2e_test_case"

class BotListenerE2eTest < E2eTestCase
  test "bot responds to /ping command via listener" do
    user = create_test_account(name: "e2e-user")
    bot_pubkey = create_test_account(name: "e2e-pingbot")

    group_id = create_test_group(creator: user, members: [ bot_pubkey ], name: "ping-test")
    skip "Could not create group" unless group_id

    # Create bot in Rails as stopped
    bot = Bot.create!(name: "E2E PingBot", npub: bot_pubkey, status: :stopped)
    bot.commands.create!(name: "Ping", pattern: "/ping", response_text: '"pong"', enabled: true)

    # Start listener first (it will reconcile, find no starting bots)
    listener = BotListener.new(sync_interval: 1)
    listener_thread = Thread.new { listener.run }
    sleep 2 # Let reconciliation finish

    # NOW set bot to starting — listener's next sync will pick it up
    bot.update!(status: :starting)
    sleep 5 # Let listener start streams for the bot's groups

    bot.reload
    assert_equal "running", bot.status, "Bot should be running, got: #{bot.status} (error: #{bot.error_message})"

    # Send /ping from the user account
    @wnd.send_message(account: user, group_id: group_id, message: "/ping")
    sleep 8 # Wait for message to arrive via relay and be processed

    # Check message logs
    bot.reload
    incoming = bot.message_logs.incoming.where(group_id: group_id).last
    outgoing = bot.message_logs.outgoing.where(group_id: group_id).last

    listener.shutdown
    listener_thread.join(5)

    assert incoming, "Expected incoming /ping message log. Logs: #{bot.message_logs.pluck(:direction, :content).inspect}"
    assert_equal "/ping", incoming.content
    assert outgoing, "Expected outgoing pong message log. Logs: #{bot.message_logs.pluck(:direction, :content).inspect}"
    assert_equal "pong", outgoing.content
  ensure
    listener&.shutdown
    listener_thread&.kill
    bot&.destroy
  end

  test "bot responds to a script command via listener" do
    user = create_test_account(name: "e2e-script-user")
    bot_pubkey = create_test_account(name: "e2e-scriptbot")

    group_id = create_test_group(creator: user, members: [ bot_pubkey ], name: "script-test")
    skip "Could not create group" unless group_id

    # Create bot with a script command
    bot = Bot.create!(name: "E2E ScriptBot", npub: bot_pubkey, status: :stopped)
    bot.commands.create!(
      name: "Coin Flip",
      pattern: "/flip",
      response_text: "%w[Heads Tails].sample",
      enabled: true
    )

    # Start listener
    listener = BotListener.new(sync_interval: 1)
    listener_thread = Thread.new { listener.run }
    sleep 2

    bot.update!(status: :starting)
    sleep 5

    bot.reload
    assert_equal "running", bot.status, "Bot should be running, got: #{bot.status} (error: #{bot.error_message})"

    # Send /flip from user account
    @wnd.send_message(account: user, group_id: group_id, message: "/flip")
    sleep 8

    bot.reload
    incoming = bot.message_logs.incoming.where(group_id: group_id).last
    outgoing = bot.message_logs.outgoing.where(group_id: group_id).last

    listener.shutdown
    listener_thread.join(5)

    assert incoming, "Expected incoming /flip message log. Logs: #{bot.message_logs.pluck(:direction, :content).inspect}"
    assert_equal "/flip", incoming.content
    assert outgoing, "Expected outgoing script response. Logs: #{bot.message_logs.pluck(:direction, :content).inspect}"
    assert_includes %w[Heads Tails], outgoing.content
  ensure
    listener&.shutdown
    listener_thread&.kill
    bot&.destroy
  end

  test "bot auto-accepts group invitation" do
    user = create_test_account(name: "e2e-inviter")
    bot_pubkey = create_test_account(name: "e2e-invitebot")

    bot = Bot.create!(name: "E2E InviteBot", npub: bot_pubkey, status: :stopped, auto_accept_invitations: true)

    # Start listener, let it reconcile
    listener = BotListener.new(sync_interval: 1)
    listener_thread = Thread.new { listener.run }
    sleep 2

    # Start the bot
    bot.update!(status: :starting)
    sleep 3

    # Create group with bot as member — wnd sends a welcome/invite
    group_id = create_test_group(creator: user, members: [ bot_pubkey ], name: "invite-test")
    skip "Could not create group" unless group_id

    # Wait for auto-accept via listener
    sleep 8

    groups = @wnd.groups_list(account: bot_pubkey)
    group_ids = groups.filter_map { |g| extract_mls_group_id(g.dig("group", "mls_group_id")) }

    listener.shutdown
    listener_thread.join(5)

    assert_includes group_ids, group_id, "Bot should have auto-accepted the group invitation"
  ensure
    listener&.shutdown
    listener_thread&.kill
    bot&.destroy
  end
end
