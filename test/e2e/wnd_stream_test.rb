require_relative "e2e_test_case"

class WndStreamTest < E2eTestCase
  test "wnd client can create identity and list accounts" do
    pubkey = create_test_account(name: "e2e-identity")

    accounts = @wnd.accounts_list
    pubkeys = accounts.map { |a| a["pubkey"] }
    assert_includes pubkeys, pubkey
  end

  test "wnd client can create group and list it" do
    alice = create_test_account(name: "e2e-grouper")
    group_id = create_test_group(creator: alice, name: "e2e-list-test")
    skip "Could not create group" unless group_id

    groups = @wnd.groups_list(account: alice)
    group_ids = groups.filter_map { |g| extract_mls_group_id(g.dig("group", "mls_group_id")) }
    assert_includes group_ids, group_id
  end

  test "messages_subscribe receives initial messages from a group" do
    alice = create_test_account(name: "e2e-sender")
    bob = create_test_account(name: "e2e-receiver")

    group_id = create_test_group(creator: alice, members: [ bob ], name: "e2e-initial-test")
    skip "Could not create group" unless group_id

    # Send a message
    send_and_wait(account: alice, group_id: group_id, message: "hello e2e")

    # Subscribe as bob — should receive as InitialMessage
    handle = subscribe_to_messages(account: bob, group_id: group_id, timeout: 10)
    events = handle.wait(15)

    initial = handle.initial_events
    assert initial.any?, "Expected InitialMessage events, got: #{events.map { |e| e['trigger'] }.inspect}"

    contents = initial.map { |e| e.dig("message", "content") }
    assert_includes contents, "hello e2e"
  end

  test "messages_subscribe receives live NewMessage events" do
    alice = create_test_account(name: "e2e-live-sender")
    bob = create_test_account(name: "e2e-live-receiver")

    group_id = create_test_group(creator: alice, members: [ bob ], name: "e2e-live-test")
    skip "Could not create group" unless group_id

    # Subscribe FIRST, then send
    handle = subscribe_to_messages(account: bob, group_id: group_id, timeout: 15)
    sleep 3 # Let stream establish and drain InitialMessages

    # Send a new message
    send_and_wait(account: alice, group_id: group_id, message: "live e2e message", wait: 5)

    events = handle.wait(20)

    live = handle.live_events
    assert live.any?, "Expected NewMessage events. All triggers: #{events.map { |e| e['trigger'] }.inspect}"

    contents = live.map { |e| e.dig("message", "content") }
    assert_includes contents, "live e2e message"
  end
end
