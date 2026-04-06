class WebhookDelivery < ApplicationRecord
  belongs_to :webhook_endpoint

  validates :event_type, presence: true
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
