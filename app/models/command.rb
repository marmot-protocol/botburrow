class Command < ApplicationRecord
  belongs_to :bot

  enum :response_type, { static: 0, template: 1, webhook: 2 }, default: :static

  validates :name, presence: true
  validates :pattern, presence: true, uniqueness: { scope: :bot_id }
  validates :response_text, presence: true

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

  def render_response(context = {})
    return response_text if static?

    response_text.gsub(/\{\{(\w+)\}\}/) do |match|
      key = $1.to_sym
      context.key?(key) ? context[key].to_s : match
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
#  response_text :text             not null
#  response_type :integer          default("static"), not null
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
