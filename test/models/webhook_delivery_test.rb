require "test_helper"

class WebhookDeliveryTest < ActiveSupport::TestCase
  test "valid delivery" do
    bot = bots(:relay_bot)
    endpoint = bot.webhook_endpoints.create!(name: "Test", url: "https://example.com")
    delivery = WebhookDelivery.new(
      webhook_endpoint: endpoint,
      event_type: "command",
      request_body: '{"test": true}',
      response_body: "ok",
      response_status: 200,
      success: true,
      delivered_at: Time.current
    )
    assert delivery.valid?
  end

  test "requires event_type" do
    bot = bots(:relay_bot)
    endpoint = bot.webhook_endpoints.create!(name: "Test", url: "https://example.com")
    delivery = WebhookDelivery.new(webhook_endpoint: endpoint)
    assert_not delivery.valid?
    assert_includes delivery.errors[:event_type], "can't be blank"
  end

  test "requires webhook_endpoint" do
    delivery = WebhookDelivery.new(event_type: "command")
    assert_not delivery.valid?
    assert_includes delivery.errors[:webhook_endpoint], "must exist"
  end

  test "belongs to a webhook_endpoint" do
    bot = bots(:relay_bot)
    endpoint = bot.webhook_endpoints.create!(name: "Test", url: "https://example.com")
    delivery = endpoint.webhook_deliveries.create!(
      event_type: "command",
      success: false,
      delivered_at: Time.current
    )
    assert_equal endpoint, delivery.webhook_endpoint
  end
end

# == Schema Information
#
# Table name: webhook_deliveries
#
#  id                  :integer          not null, primary key
#  delivered_at        :datetime
#  event_type          :string           not null
#  request_body        :text
#  response_body       :text
#  response_status     :integer
#  success             :boolean          default(FALSE), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  webhook_endpoint_id :integer          not null
#
# Indexes
#
#  index_webhook_deliveries_on_webhook_endpoint_id  (webhook_endpoint_id)
#
# Foreign Keys
#
#  webhook_endpoint_id  (webhook_endpoint_id => webhook_endpoints.id)
#
