class MessageLog < ApplicationRecord
  belongs_to :bot

  validates :group_id, :author, :content, :direction, :message_at, presence: true

  scope :incoming, -> { where(direction: "incoming") }
  scope :outgoing, -> { where(direction: "outgoing") }
  scope :recent, -> { order(message_at: :desc) }
end

# == Schema Information
#
# Table name: message_logs
#
#  id         :integer          not null, primary key
#  author     :string           not null
#  content    :text             not null
#  direction  :string           not null
#  message_at :datetime         not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  bot_id     :integer          not null
#  group_id   :string           not null
#
# Indexes
#
#  index_message_logs_on_bot_id                 (bot_id)
#  index_message_logs_on_bot_id_and_group_id    (bot_id,group_id)
#  index_message_logs_on_bot_id_and_message_at  (bot_id,message_at)
#
# Foreign Keys
#
#  bot_id  (bot_id => bots.id)
#
