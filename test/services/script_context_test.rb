require "test_helper"
require "webmock/minitest"

class ScriptContextTest < ActiveSupport::TestCase
  setup do
    @bot = Bot.create!(name: "CtxBot", npub: SecureRandom.hex(32), status: :running)
    @group_id = "testgroup1"
  end

  test "exposes message, author, args, bot_name, and group_id as readers" do
    ctx = build_context

    assert_equal "hello world", ctx.message
    assert_equal "alice", ctx.author
    assert_equal "world", ctx.args
    assert_equal "CtxBot", ctx.bot_name
    assert_equal @group_id, ctx.group_id
  end

  test "store returns a ScriptStore instance" do
    ctx = build_context
    assert_instance_of ScriptStore, ctx.store
  end

  test "send_message calls the sender proc" do
    sent = []
    ctx = build_context(sender: ->(text) { sent << text })

    ctx.send_message("hello")
    ctx.send_message("world")

    assert_equal %w[hello world], sent
  end

  test "send_message raises without sender" do
    ctx = build_context(sender: nil)

    error = assert_raises(RuntimeError) { ctx.send_message("hello") }
    assert_equal "No sender configured", error.message
  end

  test "exec raises with clear message" do
    ctx = build_context
    error = assert_raises(RuntimeError) { ctx.exec("ls") }
    assert_includes error.message, "exec is not available"
  end

  test "fork raises with clear message" do
    ctx = build_context
    error = assert_raises(RuntimeError) { ctx.fork }
    assert_includes error.message, "fork is not available"
  end

  test "at_exit raises with clear message" do
    ctx = build_context
    error = assert_raises(RuntimeError) { ctx.at_exit { puts "bye" } }
    assert_includes error.message, "at_exit is not available"
  end

  test "does not expose bot as attr_reader" do
    ctx = build_context
    assert_not ctx.respond_to?(:bot)
  end

  # --- HTTP helper tests ---

  test "http_get returns parsed JSON for JSON responses" do
    stub_request(:get, /api\.example\.com/)
      .to_return(status: 200, body: '{"temp": 72}', headers: { "Content-Type" => "application/json" })

    ctx = build_context
    stub_dns("93.184.216.34") do
      result = ctx.http_get("https://api.example.com/data")
      assert_equal({ "temp" => 72 }, result)
    end
  end

  test "http_get returns raw string for non-JSON responses" do
    stub_request(:get, /example\.com/)
      .to_return(status: 200, body: "hello plain", headers: { "Content-Type" => "text/plain" })

    ctx = build_context
    stub_dns("93.184.216.34") do
      result = ctx.http_get("https://example.com/plain")
      assert_equal "hello plain", result
    end
  end

  test "http_get sends default User-Agent header" do
    stub_request(:get, /example\.com/)
      .with(headers: { "User-Agent" => "BotBurrow/1.0" })
      .to_return(status: 200, body: "ok")

    ctx = build_context
    stub_dns("93.184.216.34") do
      result = ctx.http_get("https://example.com/ua")
      assert_equal "ok", result
    end
  end

  test "http_get passes custom headers" do
    stub_request(:get, /example\.com/)
      .with(headers: { "Authorization" => "Bearer tok123" })
      .to_return(status: 200, body: "ok")

    ctx = build_context
    stub_dns("93.184.216.34") do
      result = ctx.http_get("https://example.com/auth", headers: { "Authorization" => "Bearer tok123" })
      assert_equal "ok", result
    end
  end

  test "http_get raises on non-2xx response" do
    stub_request(:get, /example\.com/)
      .to_return(status: 404, body: "not found")

    ctx = build_context
    stub_dns("93.184.216.34") do
      error = assert_raises(RuntimeError) { ctx.http_get("https://example.com/fail") }
      assert_includes error.message, "HTTP 404"
      assert_includes error.message, "example.com"
    end
  end

  test "http_get follows one redirect" do
    stub_request(:get, /example\.com\/old/)
      .to_return(status: 301, headers: { "Location" => "https://example.com/new" })
    stub_request(:get, /example\.com\/new/)
      .to_return(status: 200, body: "arrived")

    ctx = build_context
    stub_dns("93.184.216.34") do
      result = ctx.http_get("https://example.com/old")
      assert_equal "arrived", result
    end
  end

  test "http_get raises on too many redirects" do
    stub_request(:get, /example\.com\/a/)
      .to_return(status: 301, headers: { "Location" => "https://example.com/b" })
    stub_request(:get, /example\.com\/b/)
      .to_return(status: 301, headers: { "Location" => "https://example.com/c" })

    ctx = build_context
    stub_dns("93.184.216.34") do
      error = assert_raises(RuntimeError) { ctx.http_get("https://example.com/a") }
      assert_includes error.message, "Too many redirects"
    end
  end

  test "http_get rejects requests to loopback IPs (SSRF protection)" do
    ctx = build_context
    stub_dns("127.0.0.1") do
      error = assert_raises(RuntimeError) { ctx.http_get("https://evil.com/steal") }
      assert_includes error.message, "private/internal address"
    end
  end

  test "http_get rejects requests to RFC 1918 addresses" do
    ctx = build_context
    stub_dns("10.0.0.1") do
      error = assert_raises(RuntimeError) { ctx.http_get("https://internal.com/data") }
      assert_includes error.message, "private/internal address"
    end
  end

  test "http_get rejects link-local addresses" do
    ctx = build_context
    stub_dns("169.254.1.1") do
      error = assert_raises(RuntimeError) { ctx.http_get("https://link-local.com/data") }
      assert_includes error.message, "private/internal address"
    end
  end

  test "http_get rejects IPv6 loopback" do
    ctx = build_context
    stub_dns("::1") do
      error = assert_raises(RuntimeError) { ctx.http_get("https://ipv6loop.com/data") }
      assert_includes error.message, "private/internal address"
    end
  end

  test "http_get raises on DNS resolution failure" do
    ctx = build_context
    stub_dns(nil) do
      error = assert_raises(RuntimeError) { ctx.http_get("https://nonexistent.invalid/data") }
      assert_includes error.message, "DNS resolution failed"
    end
  end

  test "http_post sends JSON body when body is a Hash" do
    stub_request(:post, /api\.example\.com/)
      .with(
        body: '{"name":"test"}',
        headers: { "Content-Type" => "application/json" }
      )
      .to_return(status: 201, body: '{"id": 1}', headers: { "Content-Type" => "application/json" })

    ctx = build_context
    stub_dns("93.184.216.34") do
      result = ctx.http_post("https://api.example.com/create", body: { name: "test" })
      assert_equal({ "id" => 1 }, result)
    end
  end

  test "http_post sends string body as-is" do
    stub_request(:post, /api\.example\.com/)
      .with(body: "raw data")
      .to_return(status: 200, body: "ok")

    ctx = build_context
    stub_dns("93.184.216.34") do
      result = ctx.http_post("https://api.example.com/raw", body: "raw data")
      assert_equal "ok", result
    end
  end

  test "http_get does not include query params in error message" do
    stub_request(:get, /example\.com/)
      .to_return(status: 500, body: "error")

    ctx = build_context
    stub_dns("93.184.216.34") do
      error = assert_raises(RuntimeError) { ctx.http_get("https://example.com/api?secret=key123") }
      assert_includes error.message, "example.com/api"
      assert_not_includes error.message, "secret"
    end
  end

  private

  def build_context(sender: ->(text) { }, **overrides)
    ScriptContext.new(
      bot: @bot, group_id: @group_id,
      author: "alice", message: "hello world", args: "world",
      sender: sender,
      **overrides
    )
  end

  # Stubs Resolv.getaddresses to return the given IP (or empty array if nil).
  def stub_dns(ip)
    addresses = ip ? [ ip ] : []
    original = Resolv.method(:getaddresses)
    Resolv.define_singleton_method(:getaddresses) { |_host| addresses }
    yield
  ensure
    Resolv.define_singleton_method(:getaddresses, original)
  end
end
