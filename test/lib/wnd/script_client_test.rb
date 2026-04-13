require "test_helper"

class Wnd::ScriptClientTest < ActiveSupport::TestCase
  setup do
    @stub = StubClient.new
    @script_client = Wnd::ScriptClient.new(@stub, account: "npub1bot")
  end

  test "user delegates to users_show with the given pubkey" do
    @stub.stub(:users_show, { "metadata" => { "name" => "Alice" } }) do
      result = @script_client.user("pubkey_alice")
      assert_equal "Alice", result.dig("metadata", "name")
    end

    assert_equal({ pubkey: "pubkey_alice" }, @stub.last_call(:users_show))
  end

  test "groups delegates to groups_list with pre-bound account" do
    @script_client.groups
    assert_equal({ account: "npub1bot" }, @stub.last_call(:groups_list))
  end

  test "invites delegates to groups_invites with pre-bound account" do
    @script_client.invites
    assert_equal({ account: "npub1bot" }, @stub.last_call(:groups_invites))
  end

  test "profile delegates to profile_show with pre-bound account" do
    @script_client.profile
    assert_equal({ account: "npub1bot" }, @stub.last_call(:profile_show))
  end

  test "members delegates to group_members with pre-bound account and given group_id" do
    @script_client.members("group123")
    assert_equal({ account: "npub1bot", group_id: "group123" }, @stub.last_call(:group_members))
  end

  test "accept_invite delegates to groups_accept with pre-bound account" do
    @script_client.accept_invite("group456")
    assert_equal({ account: "npub1bot", group_id: "group456" }, @stub.last_call(:groups_accept))
  end

  test "decline_invite delegates to groups_decline with pre-bound account" do
    @script_client.decline_invite("group789")
    assert_equal({ account: "npub1bot", group_id: "group789" }, @stub.last_call(:groups_decline))
  end

  test "does not expose excluded client methods" do
    %i[create_identity accounts_list keys_publish logout create_group
       add_members send_message messages_subscribe daemon_status].each do |method|
      assert_not @script_client.respond_to?(method), "ScriptClient should not expose #{method}"
    end
  end

  private

  # Minimal stub that records calls and returns canned values.
  class StubClient
    def initialize
      @calls = {}
      @stubs = {}
    end

    def last_call(method) = @calls[method]

    def stub(method, value)
      @stubs[method] = value
      yield
    ensure
      @stubs.delete(method)
    end

    def method_missing(name, **kwargs)
      @calls[name] = kwargs
      @stubs[name]
    end

    def respond_to_missing?(name, include_private = false)
      true
    end
  end
end
