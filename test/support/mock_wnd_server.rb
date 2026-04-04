require "socket"
require "json"
require "tmpdir"

class MockWndServer
  attr_reader :socket_path

  def initialize
    @socket_path = File.join(Dir.tmpdir, "test_wnd_#{Process.pid}_#{object_id}.sock")
    @handler = ->(_request) { { "result" => "ok" } }
    @server = UNIXServer.new(@socket_path)
    @threads = []
    @running = true
    start_accept_loop
  end

  def on_request(&block)
    @handler = block
  end

  def shutdown
    @running = false
    @server.close rescue nil
    @threads.each { |t| t.join(2) }
    File.delete(@socket_path) if File.exist?(@socket_path)
  end

  private

  def start_accept_loop
    @accept_thread = Thread.new do
      while @running
        begin
          client = @server.accept
          @threads << Thread.new(client) { |c| handle_client(c) }
        rescue IOError, Errno::EBADF
          break
        end
      end
    end
    @threads << @accept_thread
  end

  def handle_client(client)
    line = client.gets
    return unless line

    request = JSON.parse(line)
    response = @handler.call(request)

    if response.is_a?(String)
      client.puts(response)
    elsif response.is_a?(Array)
      response.each do |msg|
        client.puts(msg.is_a?(String) ? msg : JSON.generate(msg))
      end
    else
      client.puts(JSON.generate(response))
    end
  rescue JSON::ParserError
    client.puts(JSON.generate({ "error" => "parse error" }))
  rescue Errno::EPIPE, IOError
    # Client disconnected, expected in timeout tests
  ensure
    client.close rescue nil
  end
end
