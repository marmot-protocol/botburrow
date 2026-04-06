class WebhookDispatcher
  TIMEOUT = 10

  def initialize(endpoint)
    @endpoint = endpoint
  end

  def deliver(payload)
    body = JSON.generate(payload)
    signature = compute_signature(body)
    uri = URI(@endpoint.url)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = TIMEOUT
    http.read_timeout = TIMEOUT

    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["X-Botburrow-Signature"] = signature if signature
    request.body = body

    response = http.request(request)

    delivery = @endpoint.webhook_deliveries.create!(
      event_type: payload[:event] || payload["event"],
      request_body: body,
      response_body: response.body,
      response_status: response.code.to_i,
      success: response.code.to_i.between?(200, 299),
      delivered_at: Time.current
    )

    [ delivery, response ]
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH => e
    delivery = @endpoint.webhook_deliveries.create!(
      event_type: payload[:event] || payload["event"],
      request_body: body,
      response_body: "#{e.class}: #{e.message}",
      success: false,
      delivered_at: Time.current
    )

    [ delivery, nil ]
  end

  private

  def compute_signature(body)
    return nil unless @endpoint.secret.present?

    "sha256=#{OpenSSL::HMAC.hexdigest("SHA256", @endpoint.secret, body)}"
  end
end
