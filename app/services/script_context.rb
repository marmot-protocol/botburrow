require "net/http"
require "resolv"
require "ipaddr"

class ScriptContext
  attr_reader :message, :author, :args, :bot_name, :group_id, :wnd

  def initialize(bot:, group_id:, author:, message:, args:, sender: nil, wnd: nil)
    @bot = bot
    @group_id = group_id
    @author = author
    @message = message
    @args = args
    @bot_name = bot.name
    @sender = sender
    @wnd = wnd
  end

  def send_message(text)
    raise "No sender configured" unless @sender
    @sender.call(text.to_s)
    nil
  end

  def exec(*)  = raise("exec is not available in scripts — it would replace the server process")
  def fork(*)  = raise("fork is not available in scripts — use http_get for async work")
  def at_exit(*) = raise("at_exit is not available in scripts")

  def store
    @store ||= ScriptStore.new(@bot)
  end

  def files
    @files ||= ScriptFiles.new(@bot)
  end

  def http_get(url, headers: {}, timeout: 10)
    uri = URI(url)
    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = "BotBurrow/1.0"
    headers.each { |k, v| request[k] = v }
    perform_http_request(uri, request, timeout: timeout)
  end

  def http_post(url, body: nil, headers: {}, timeout: 10)
    uri = URI(url)
    request = Net::HTTP::Post.new(uri)
    request["User-Agent"] = "BotBurrow/1.0"

    if body.is_a?(Hash)
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(body)
    elsif body
      request.body = body.to_s
    end

    headers.each { |k, v| request[k] = v }
    perform_http_request(uri, request, timeout: timeout)
  end

  private

  PRIVATE_RANGES = [
    IPAddr.new("10.0.0.0/8"),
    IPAddr.new("172.16.0.0/12"),
    IPAddr.new("192.168.0.0/16"),
    IPAddr.new("127.0.0.0/8"),
    IPAddr.new("169.254.0.0/16"),
    IPAddr.new("::1/128"),
    IPAddr.new("fc00::/7"),
    IPAddr.new("fe80::/10")
  ].freeze

  MAX_BODY_SIZE = 1_048_576 # 1MB

  def perform_http_request(uri, request, timeout:, redirects_remaining: 1)
    resolved_ip = resolve_and_check(uri.host)

    http = Net::HTTP.new(uri.host, uri.port || (uri.scheme == "https" ? 443 : 80))
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = timeout
    http.read_timeout = timeout
    http.ipaddr = resolved_ip if http.respond_to?(:ipaddr=)

    if http.use_ssl?
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    end

    response = http.request(request)

    if response.is_a?(Net::HTTPRedirection) && redirects_remaining > 0
      redirect_uri = URI(response["location"])
      redirect_uri = URI.join("#{uri.scheme}://#{uri.host}:#{uri.port}", response["location"]) unless redirect_uri.host
      new_request = Net::HTTP::Get.new(redirect_uri)
      new_request["User-Agent"] = "BotBurrow/1.0"
      return perform_http_request(redirect_uri, new_request, timeout: timeout, redirects_remaining: redirects_remaining - 1)
    elsif response.is_a?(Net::HTTPRedirection)
      raise "Too many redirects (#{uri} -> #{response['location']})"
    end

    unless response.code.to_i.between?(200, 299)
      safe_url = "#{uri.scheme}://#{uri.host}#{uri.path}"
      raise "HTTP #{response.code} from #{safe_url}"
    end

    body = read_body_with_limit(response)
    parse_response_body(body, response["content-type"])
  end

  def resolve_and_check(host)
    addresses = Resolv.getaddresses(host)
    raise "DNS resolution failed for #{host}" if addresses.empty?

    addresses.each do |addr_str|
      addr = IPAddr.new(addr_str)
      if PRIVATE_RANGES.any? { |range| range.include?(addr) }
        raise "Request to private/internal address #{addr_str} is not allowed"
      end
    end

    addresses.first
  end

  def read_body_with_limit(response)
    body = +""
    response.read_body do |chunk|
      body << chunk
      if body.bytesize > MAX_BODY_SIZE
        raise "Response body exceeds 1MB limit"
      end
    end
    body.force_encoding("UTF-8")
  rescue IOError
    # Response already read (e.g., in test stubs)
    (response.body || "").force_encoding("UTF-8")
  end

  def parse_response_body(body, content_type)
    return JSON.parse(body) if content_type&.include?("application/json")
    body
  end
end
