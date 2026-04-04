require "test_helper"
require "support/mock_wnd_server"

class Wnd::ClientTest < ActiveSupport::TestCase
  setup do
    @server = MockWndServer.new
    @client = Wnd::Client.new(socket_path: @server.socket_path)
  end

  teardown do
    @server.shutdown
  end

  test "sends a request and returns the result" do
    @server.on_request do |req|
      assert_equal "ping", req["method"]
      { "result" => { "version" => "0.1.0" } }
    end

    result = @client.daemon_status
    assert_equal({ "version" => "0.1.0" }, result)
  end

  test "raises ConnectionError when socket does not exist" do
    client = Wnd::Client.new(socket_path: "/tmp/nonexistent_#{Process.pid}.sock")

    assert_raises(Wnd::ConnectionError) { client.daemon_status }
  end

  test "raises Error with message when wnd returns an error response" do
    @server.on_request do |_req|
      { "error" => "account not found" }
    end

    error = assert_raises(Wnd::Error) { @client.daemon_status }
    assert_equal "account not found", error.message
  end

  test "raises ConnectionError when response is not valid JSON" do
    @server.on_request do |_req|
      "this is not json at all"
    end

    assert_raises(Wnd::ConnectionError) { @client.daemon_status }
  end

  test "raises TimeoutError when stream receives no data within timeout" do
    @server.on_request do |_req|
      sleep 2
      { "result" => "too late" }
    end

    client = Wnd::Client.new(socket_path: @server.socket_path, timeout: 0.1)

    assert_raises(Wnd::TimeoutError) do
      client.notifications_subscribe { |_event| }
    end
  end

  test "streaming yields multiple results until stream_end" do
    @server.on_request do |req|
      assert_equal "notifications_subscribe", req["method"]
      assert_nil req["params"]

      [
        { "result" => { "type" => "message", "content" => "hello" } },
        { "result" => { "type" => "message", "content" => "world" } },
        { "stream_end" => true }
      ]
    end

    events = []
    @client.notifications_subscribe do |event|
      events << event
    end

    assert_equal 2, events.size
    assert_equal "hello", events[0]["content"]
    assert_equal "world", events[1]["content"]
  end

  test "create_identity strips nsec from response" do
    @server.on_request do |req|
      assert_equal "create_identity", req["method"]
      assert_nil req["params"]
      { "result" => { "pubkey" => "abc123", "nsec" => "nsec1secret" } }
    end

    result = @client.create_identity
    assert_equal "abc123", result["pubkey"]
    assert_nil result["nsec"]
  end

  test "omits params key for parameterless requests" do
    @server.on_request do |req|
      assert_equal "ping", req["method"]
      assert_nil req["params"]
      { "result" => "ok" }
    end

    @client.daemon_status
  end

  test "accounts_list sends correct method name" do
    @server.on_request do |req|
      assert_equal "all_accounts", req["method"]
      { "result" => [ { "npub" => "npub1a" }, { "npub" => "npub1b" } ] }
    end

    result = @client.accounts_list
    assert_equal 2, result.size
  end

  test "keys_publish sends account param" do
    @server.on_request do |req|
      assert_equal "keys_publish", req["method"]
      assert_equal "npub1abc", req["params"]["account"]
      { "result" => { "published" => true } }
    end

    @client.keys_publish(account: "npub1abc")
  end

  test "groups_invites sends correct method name" do
    @server.on_request do |req|
      assert_equal "group_invites", req["method"]
      { "result" => [] }
    end

    @client.groups_invites(account: "npub1abc")
  end

  test "groups_accept sends correct method name and params" do
    @server.on_request do |req|
      assert_equal "accept_invite", req["method"]
      assert_equal "npub1abc", req["params"]["account"]
      assert_equal "group123", req["params"]["group_id"]
      { "result" => { "accepted" => true } }
    end

    @client.groups_accept(account: "npub1abc", group_id: "group123")
  end

  test "send_message sends all params" do
    @server.on_request do |req|
      assert_equal "send_message", req["method"]
      assert_equal "npub1abc", req["params"]["account"]
      assert_equal "group123", req["params"]["group_id"]
      assert_equal "pong", req["params"]["message"]
      { "result" => { "sent" => true } }
    end

    @client.send_message(account: "npub1abc", group_id: "group123", message: "pong")
  end
end
