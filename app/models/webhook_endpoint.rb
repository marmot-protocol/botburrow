class WebhookEndpoint < ApplicationRecord
  belongs_to :bot
  has_many :webhook_deliveries, dependent: :destroy

  validates :name, presence: true
  validates :url, presence: true,
    format: { with: /\Ahttps?:\/\//i, message: "must start with http:// or https://" }

  scope :enabled, -> { where(enabled: true) }
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
