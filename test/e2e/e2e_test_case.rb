require "test_helper"

# Base class for end-to-end tests that talk to a real wnd daemon.
#
# These tests are opt-in: run with `bin/rails test:e2e` or `E2E=1 bin/rails test test/e2e/`.
# They require a running wnd daemon and will create/cleanup test accounts.
#
# Each test gets a fresh Wnd::Client and helper methods for common operations.
class E2eTestCase < ActiveSupport::TestCase
  setup do
    skip "E2E tests require running wnd (run with E2E=1)" unless ENV["E2E"]
    @created_accounts = []
    @stream_handles = []
    @wnd = Wnd::Client.new
    verify_wnd_running!
  end

  teardown do
    return unless ENV["E2E"]
    stop_all_streams
    cleanup_test_accounts
  end

  private

  def verify_wnd_running!
    @wnd.daemon_status
  rescue Wnd::ConnectionError => e
    skip "wnd is not running: #{e.message}"
  end

  # Create a new test account and track it for cleanup.
  # Retries once if wnd connection drops during key publishing.
  def create_test_account(name: "e2e-test-#{SecureRandom.hex(4)}")
    result = @wnd.create_identity
    pubkey = result["pubkey"]
    @created_accounts << pubkey

    @wnd.keys_publish(account: pubkey)
    @wnd.profile_update(account: pubkey, name: name)
    sleep 2 # relay propagation for key packages
    pubkey
  rescue Wnd::Error => e
    raise "Failed to create test account: #{e.message}"
  end

  # Create a group between two accounts
  def create_test_group(creator:, members: [], name: "e2e-group-#{SecureRandom.hex(4)}")
    result = @wnd.create_group(account: creator, name: name, members: members)
    group_id = extract_group_id_from_response(result)

    if members.any?
      sleep 3
      members.each { |member| accept_pending_invites(member) }
      sleep 1
    end

    group_id
  end

  # Accept all pending invites for an account
  def accept_pending_invites(account)
    invites = @wnd.groups_invites(account: account)
    return unless invites.is_a?(Array)

    invites.each do |inv|
      group_id = extract_group_id_from_invite(inv)
      @wnd.groups_accept(account: account, group_id: group_id) if group_id
    end
  rescue Wnd::Error => e
    puts "[e2e] Failed to accept invites for #{account[0..8]}...: #{e.message}"
  end

  # Open a messages_subscribe stream in a thread, collect events.
  # Tracked for automatic cleanup in teardown.
  def subscribe_to_messages(account:, group_id:, timeout: 15)
    events = []
    stream_wnd = Wnd::Client.new(timeout: timeout)

    thread = Thread.new do
      stream_wnd.messages_subscribe(account: account, group_id: group_id) do |event|
        events << event
      end
    rescue Wnd::TimeoutError
      # Expected — stream times out when no more events
    rescue => e
      events << { "error" => e.message }
    end

    handle = StreamHandle.new(thread: thread, events: events)
    @stream_handles << handle
    handle
  end

  # Send a message and wait briefly for propagation
  def send_and_wait(account:, group_id:, message:, wait: 2)
    @wnd.send_message(account: account, group_id: group_id, message: message)
    sleep wait
  end

  def extract_group_id_from_response(result)
    return nil unless result.is_a?(Hash)
    mls_group_id = result["mls_group_id"] || result.dig("group", "mls_group_id")
    extract_mls_group_id(mls_group_id)
  end

  def extract_group_id_from_invite(invite)
    mls_group_id = invite["mls_group_id"] || invite.dig("group", "mls_group_id")
    extract_mls_group_id(mls_group_id)
  end

  def extract_mls_group_id(mls_group_id)
    return mls_group_id if mls_group_id.is_a?(String)
    return unless mls_group_id.is_a?(Hash)
    bytes = mls_group_id.dig("value", "vec")
    return unless bytes.is_a?(Array)
    bytes.pack("C*").unpack1("H*")
  end

  # Kill all open stream threads
  def stop_all_streams
    @stream_handles&.each do |handle|
      handle.thread.kill if handle.thread.alive?
      handle.thread.join(2)
    rescue
      nil
    end
  end

  # Log out all test-created accounts and delete their MLS files.
  # Best-effort: failures are logged but don't raise.
  def cleanup_test_accounts
    return unless @created_accounts&.any?

    @created_accounts.each do |pubkey|
      @wnd.logout(pubkey: pubkey)
    rescue Wnd::Error => e
      puts "[e2e cleanup] Failed to logout #{pubkey[0..8]}...: #{e.message}"
    rescue Wnd::ConnectionError
      # wnd is down — clean up MLS file directly
      cleanup_mls_file(pubkey)
    end
  end

  # Delete MLS database file for an account (fallback when wnd is unavailable)
  def cleanup_mls_file(pubkey)
    mls_dir = if RUBY_PLATFORM.include?("darwin")
      File.join(Dir.home, "Library", "Application Support", "whitenoise-cli")
    else
      File.join(ENV.fetch("XDG_DATA_HOME", File.join(Dir.home, ".local", "share")), "whitenoise-cli")
    end
    mode = ENV.fetch("WND_BUILD_MODE", "release")
    path = File.join(mls_dir, mode, "mls", pubkey)

    if File.exist?(path)
      File.delete(path)
      puts "[e2e cleanup] Deleted MLS file for #{pubkey[0..8]}..."
    end
  rescue => e
    puts "[e2e cleanup] Failed to delete MLS file for #{pubkey[0..8]}...: #{e.message}"
  end

  # Simple struct to hold a stream thread and its collected events
  StreamHandle = Struct.new(:thread, :events, keyword_init: true) do
    def wait(timeout = 10)
      thread.join(timeout)
      thread.kill if thread.alive?
      events
    end

    def live_events
      events.select { |e| e.dig("trigger") == "NewMessage" }
    end

    def initial_events
      events.select { |e| e.dig("trigger") == "InitialMessage" }
    end
  end
end
