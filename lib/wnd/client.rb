require "socket"
require "json"

module Wnd
  class Client
    STREAM_TIMEOUT = 30

    def initialize(socket_path: Rails.configuration.wnd_socket_path, timeout: STREAM_TIMEOUT)
      @socket_path = socket_path
      @timeout = timeout
    end

    def create_identity
      result = request("create_identity")
      result.delete("nsec") if result.is_a?(Hash)
      result
    end

    def accounts_list
      request("all_accounts")
    end

    def keys_publish(account:)
      request("keys_publish", account: account)
    end

    def create_group(account:, name:, members: [])
      request("create_group", account: account, name: name, members: members)
    end

    def add_members(account:, group_id:, members:)
      request("add_members", account: account, group_id: group_id, members: members)
    end

    def logout(pubkey:)
      request("logout", pubkey: pubkey)
    end

    def groups_invites(account:)
      request("group_invites", account: account)
    end

    def groups_accept(account:, group_id:)
      request("accept_invite", account: account, group_id: group_id)
    end

    def groups_decline(account:, group_id:)
      request("decline_invite", account: account, group_id: group_id)
    end

    def groups_list(account:)
      request("visible_groups", account: account)
    end

    def notifications_subscribe(&block)
      stream("notifications_subscribe", &block)
    end

    def messages_subscribe(account:, group_id:, limit: nil, &block)
      stream("messages_subscribe", account: account, group_id: group_id, limit: limit, &block)
    end

    def send_message(account:, group_id:, message:)
      request("send_message", account: account, group_id: group_id, message: message)
    end

    def profile_update(account:, name: nil, display_name: nil, about: nil, picture: nil)
      request("profile_update", account: account, name: name, display_name: display_name, about: about, picture: picture)
    end

    def profile_show(account:)
      request("profile_show", account: account)
    end

    def daemon_status
      request("ping")
    end

    private

    def request(method, **params)
      socket = connect
      socket.puts(build_payload(method, params))
      line = read_line(socket)
      response = parse_json(line)
      raise Wnd::Error, response["error"] if response.key?("error")
      response["result"]
    ensure
      socket&.close
    end

    def stream(method, **params, &block)
      socket = connect
      socket.puts(build_payload(method, params))

      loop do
        if @timeout
          ready = IO.select([ socket ], nil, nil, @timeout)
          raise Wnd::TimeoutError, "no data from wnd within #{@timeout}s" unless ready
        end

        line = read_line(socket)
        response = parse_json(line)
        raise Wnd::Error, response["error"] if response.key?("error")
        break if response["stream_end"]

        block.call(response["result"])
      end
    ensure
      socket&.close
    end

    def build_payload(method, params)
      params = params.compact
      payload = { method: method }
      payload[:params] = params unless params.empty?
      JSON.generate(payload)
    end

    def connect
      UNIXSocket.new(@socket_path)
    rescue Errno::ENOENT, Errno::ECONNREFUSED => e
      raise Wnd::ConnectionError, e.message
    end

    def read_line(socket)
      line = socket.gets
      raise Wnd::ConnectionError, "connection closed" unless line
      line
    end

    def parse_json(line)
      JSON.parse(line)
    rescue JSON::ParserError => e
      raise Wnd::ConnectionError, "invalid JSON from wnd: #{e.message}"
    end
  end
end
