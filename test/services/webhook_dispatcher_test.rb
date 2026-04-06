require "test_helper"
require "webmock/minitest"

class WebhookDispatcherTest < ActiveSupport::TestCase
  setup do
    @bot = bots(:relay_bot)
    @endpoint = @bot.webhook_endpoints.create!(
      name: "Test Webhook",
      url: "https://example.com/webhook",
      secret: "test_secret"
    )
  end

  test "delivers payload and creates delivery record" do
    stub_request(:post, "https://example.com/webhook")
      .to_return(status: 200, body: "OK")

    dispatcher = WebhookDispatcher.new(@endpoint)
    payload = { event: "command", data: { message: "hello" } }

    assert_difference "WebhookDelivery.count", 1 do
      delivery, response = dispatcher.deliver(payload)

      assert delivery.success?
      assert_equal 200, delivery.response_status
      assert_equal "OK", delivery.response_body
      assert_equal "command", delivery.event_type
      assert_not_nil delivery.delivered_at
      assert_not_nil delivery.request_body
    end
  end

  test "records failed delivery for HTTP errors" do
    stub_request(:post, "https://example.com/webhook")
      .to_return(status: 500, body: "Internal Server Error")

    dispatcher = WebhookDispatcher.new(@endpoint)
    delivery, _response = dispatcher.deliver(event: "command")

    assert_not delivery.success?
    assert_equal 500, delivery.response_status
    assert_equal "Internal Server Error", delivery.response_body
  end

  test "records delivery on network failure" do
    stub_request(:post, "https://example.com/webhook").to_timeout

    dispatcher = WebhookDispatcher.new(@endpoint)

    assert_difference "WebhookDelivery.count", 1 do
      delivery, response = dispatcher.deliver(event: "command")

      assert_not delivery.success?
      assert_nil delivery.response_status
      assert_includes delivery.response_body, "Net::OpenTimeout"
      assert_nil response
    end
  end

  test "computes HMAC signature when secret is present" do
    stub = stub_request(:post, "https://example.com/webhook")
      .with { |request|
        sig = request.headers["X-Botburrow-Signature"]
        sig.present? && sig.start_with?("sha256=")
      }
      .to_return(status: 200, body: "OK")

    dispatcher = WebhookDispatcher.new(@endpoint)
    dispatcher.deliver(event: "command")

    assert_requested stub
  end

  test "computes correct HMAC value" do
    body = '{"event":"command"}'
    expected = "sha256=#{OpenSSL::HMAC.hexdigest("SHA256", "test_secret", body)}"

    stub = stub_request(:post, "https://example.com/webhook")
      .with(
        body: body,
        headers: { "X-Botburrow-Signature" => expected }
      )
      .to_return(status: 200, body: "OK")

    dispatcher = WebhookDispatcher.new(@endpoint)
    dispatcher.deliver(event: "command")

    assert_requested stub
  end

  test "omits signature header when no secret" do
    @endpoint.update!(secret: nil)

    stub = stub_request(:post, "https://example.com/webhook")
      .with { |request|
        !request.headers.key?("X-Botburrow-Signature")
      }
      .to_return(status: 200, body: "OK")

    dispatcher = WebhookDispatcher.new(@endpoint)
    dispatcher.deliver(event: "command")

    assert_requested stub
  end

  test "sends JSON content type" do
    stub = stub_request(:post, "https://example.com/webhook")
      .with(headers: { "Content-Type" => "application/json" })
      .to_return(status: 200, body: "OK")

    dispatcher = WebhookDispatcher.new(@endpoint)
    dispatcher.deliver(event: "command")

    assert_requested stub
  end

  test "payload is sent as JSON body" do
    stub = stub_request(:post, "https://example.com/webhook")
      .with(body: '{"event":"command","author":"alice"}')
      .to_return(status: 200, body: "OK")

    dispatcher = WebhookDispatcher.new(@endpoint)
    dispatcher.deliver(event: "command", author: "alice")

    assert_requested stub
  end
end
