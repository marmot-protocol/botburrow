class Command < ApplicationRecord
  belongs_to :bot

  enum :pattern_type, { prefix: 0, exact: 1 }, default: :prefix

  validates :name, presence: true
  validates :pattern, presence: true, uniqueness: { scope: :bot_id }
  validates :response_text, presence: true

  normalizes :name, with: -> { _1.strip }
  normalizes :pattern, with: -> { _1.strip }

  scope :enabled, -> { where(enabled: true) }

  def matches?(message_text)
    normalized_message = message_text.strip.downcase
    normalized_pattern = pattern.strip.downcase

    case pattern_type
    when "prefix" then normalized_message.start_with?(normalized_pattern)
    when "exact"  then normalized_message == normalized_pattern
    end
  end
end

# == Schema Information
#
# Table name: commands
#
#  id            :integer          not null, primary key
#  enabled       :boolean          default(TRUE), not null
#  name          :string           not null
#  pattern       :string           not null
#  pattern_type  :integer          default("prefix"), not null
#  position      :integer
#  response_text :text             not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  bot_id        :integer          not null
#
# Indexes
#
#  index_commands_on_bot_id              (bot_id)
#  index_commands_on_bot_id_and_pattern  (bot_id,pattern) UNIQUE
#
# Foreign Keys
#
#  bot_id  (bot_id => bots.id)
#
