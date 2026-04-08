class Command < ApplicationRecord
  belongs_to :bot

  enum :response_type, { script: 3 }, default: :script

  validates :name, presence: true
  validates :pattern, presence: true, uniqueness: { scope: :bot_id }
  validates :response_text, presence: true
  validate :script_body_syntax, if: -> { script? && response_text.present? }

  normalizes :name, with: -> { _1.strip }
  normalizes :pattern, with: -> { _1.strip }

  scope :enabled, -> { where(enabled: true) }

  def matches?(message_text)
    message_text.strip.downcase.start_with?(pattern.strip.downcase)
  end

  def extract_args(message_text)
    return nil unless matches?(message_text)

    message_text.strip[pattern.strip.length..].to_s.strip
  end

  private

  def script_body_syntax
    RubyVM::InstructionSequence.compile(response_text)
  rescue SyntaxError => e
    errors.add(:response_text, "has a syntax error: #{e.message}")
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
#  response_text :text             not null
#  response_type :integer          default("script"), not null
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
