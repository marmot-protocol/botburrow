class MockListenerWnd
  attr_reader :calls

  def initialize(timeout: nil, socket_path: nil)
    @calls = Concurrent::Array.new
    @streams = Concurrent::Hash.new
    @groups = Concurrent::Hash.new { |h, k| h[k] = [] }
  end

  def groups_list(account:)
    @calls << [ :groups_list, { account: account } ]
    @groups[account].map do |gid|
      { "group" => { "mls_group_id" => gid, "state" => "active", "name" => "Test" } }
    end
  end

  def messages_subscribe(account:, group_id:, limit: 0, &block)
    key = "#{account}:#{group_id}"
    @calls << [ :messages_subscribe, { account: account, group_id: group_id } ]
    queue = Queue.new
    @streams[key] = queue

    loop do
      signal = queue.pop
      break if signal == :stop
      block.call(signal) if signal.is_a?(Hash)
    end
  end

  def send_message(account:, group_id:, message:)
    @calls << [ :send_message, { account: account, group_id: group_id, message: message } ]
  end

  def groups_accept(account:, group_id:)
    @calls << [ :groups_accept, { account: account, group_id: group_id } ]
  end

  def add_group(account, group_id)
    @groups[account] << group_id
  end

  def emit_event(account, group_id, event)
    key = "#{account}:#{group_id}"
    @streams[key]&.push(event)
  end

  def disconnect_all
    @streams.each_value { |q| q.push(:stop) }
  end

  def calls_for(method)
    @calls.select { |m, _| m == method }
  end
end

# Need concurrent-ruby for thread-safe collections
require "concurrent-ruby" unless defined?(Concurrent)
