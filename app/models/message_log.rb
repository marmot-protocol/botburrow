class MessageLog < ApplicationRecord
  belongs_to :bot

  validates :group_id, :author, :content, :direction, :message_at, presence: true

  after_create_commit :broadcast_to_chat

  scope :incoming, -> { where(direction: "incoming") }
  scope :outgoing, -> { where(direction: "outgoing") }
  scope :errors, -> { where(direction: "error") }
  scope :recent, -> { order(message_at: :desc) }

  private

  def broadcast_to_chat
    return if direction == "error"

    broadcast_append_to bot, target: "chat_messages",
      partial: "chat/message",
      locals: { message: self, bot_npub: bot.npub }
  rescue => e
    Rails.logger.warn("[MessageLog] Chat broadcast failed: #{e.message}")
  end
end
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
