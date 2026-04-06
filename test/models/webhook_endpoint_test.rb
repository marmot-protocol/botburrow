require "test_helper"

class WebhookEndpointTest < ActiveSupport::TestCase
  test "valid webhook endpoint" do
    endpoint = WebhookEndpoint.new(
      bot: bots(:relay_bot),
      name: "My Webhook",
      url: "https://example.com/webhook"
    )
    assert endpoint.valid?
  end

  test "requires a name" do
    endpoint = WebhookEndpoint.new(bot: bots(:relay_bot), url: "https://example.com/webhook")
    assert_not endpoint.valid?
    assert_includes endpoint.errors[:name], "can't be blank"
  end

  test "requires a url" do
    endpoint = WebhookEndpoint.new(bot: bots(:relay_bot), name: "My Webhook")
    assert_not endpoint.valid?
    assert_includes endpoint.errors[:url], "can't be blank"
  end

  test "rejects invalid url format" do
    %w[not-a-url ftp://example.com /just/a/path].each do |bad_url|
      endpoint = WebhookEndpoint.new(bot: bots(:relay_bot), name: "Test", url: bad_url)
      assert_not endpoint.valid?, "Expected '#{bad_url}' to be invalid"
      assert_includes endpoint.errors[:url], "must start with http:// or https://"
    end
  end

  test "accepts valid http and https urls" do
    %w[http://localhost:3000/hook https://example.com/webhook http://192.168.1.1/api].each do |good_url|
      endpoint = WebhookEndpoint.new(bot: bots(:relay_bot), name: "Test", url: good_url)
      assert endpoint.valid?, "Expected '#{good_url}' to be valid, got: #{endpoint.errors.full_messages}"
    end
  end

  test "belongs to a bot" do
    endpoint = WebhookEndpoint.new(name: "My Webhook", url: "https://example.com/webhook")
    assert_not endpoint.valid?
    assert_includes endpoint.errors[:bot], "must exist"
  end

  test "enabled scope filters to enabled endpoints" do
    bot = bots(:relay_bot)
    enabled = bot.webhook_endpoints.create!(name: "Enabled", url: "https://example.com/a", enabled: true)
    disabled = bot.webhook_endpoints.create!(name: "Disabled", url: "https://example.com/b", enabled: false)

    assert_includes WebhookEndpoint.enabled, enabled
    assert_not_includes WebhookEndpoint.enabled, disabled
  end

  test "defaults to enabled" do
    endpoint = WebhookEndpoint.new(bot: bots(:relay_bot), name: "Test", url: "https://example.com")
    assert endpoint.enabled?
  end

  test "has many webhook deliveries" do
    bot = bots(:relay_bot)
    endpoint = bot.webhook_endpoints.create!(name: "Test", url: "https://example.com")
    delivery = endpoint.webhook_deliveries.create!(
      event_type: "command",
      success: false,
      delivered_at: Time.current
    )

    assert_includes endpoint.webhook_deliveries, delivery
  end

  test "destroying endpoint destroys deliveries" do
    bot = bots(:relay_bot)
    endpoint = bot.webhook_endpoints.create!(name: "Test", url: "https://example.com")
    endpoint.webhook_deliveries.create!(event_type: "command", success: false, delivered_at: Time.current)

    assert_difference "WebhookDelivery.count", -1 do
      endpoint.destroy
    end
  end

  test "destroying bot destroys webhook endpoints" do
    bot = Bot.create!(name: "HookBot", npub: "npub1hook0000000000000000000000000000000000000000000000000000")
    bot.webhook_endpoints.create!(name: "Test", url: "https://example.com")

    assert_difference "WebhookEndpoint.count", -1 do
      bot.destroy
    end
  end
end

# == Schema Information
#
# Table name: webhook_endpoints
#
#  id         :integer          not null, primary key
#  enabled    :boolean          default(TRUE), not null
#  name       :string           not null
#  secret     :string
#  url        :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  bot_id     :integer          not null
#
# Indexes
#
#  index_webhook_endpoints_on_bot_id  (bot_id)
#
# Foreign Keys
#
#  bot_id  (bot_id => bots.id)
#
