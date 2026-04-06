class Trigger < ApplicationRecord
  belongs_to :bot

  enum :event_type, { message_received: 0, member_joined: 1, member_left: 2 }
  enum :condition_type, { keyword: 0, regex: 1, any: 2 }
  enum :action_type, { reply: 0, log_only: 2 }

  validates :name, presence: true
  validates :condition_value, presence: true, unless: -> { any? }

  normalizes :name, with: -> { _1.strip }

  scope :enabled, -> { where(enabled: true) }

  def matches?(text)
    case condition_type
    when "keyword" then text.downcase.include?(condition_value.downcase)
    when "regex" then text.match?(Regexp.new(condition_value, Regexp::IGNORECASE, timeout: 1))
    when "any" then true
    end
  rescue RegexpError, Regexp::TimeoutError
    false
  end

  def parsed_action_config
    return {} unless action_config.present?
    JSON.parse(action_config)
  rescue JSON::ParserError
    {}
  end
end

# == Schema Information
#
# Table name: triggers
#
#  id              :integer          not null, primary key
#  action_config   :text
#  action_type     :integer          default("reply"), not null
#  condition_type  :integer          default("keyword"), not null
#  condition_value :string
#  enabled         :boolean          default(TRUE), not null
#  event_type      :integer          default("message_received"), not null
#  name            :string           not null
#  position        :integer
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  bot_id          :integer          not null
#
# Indexes
#
#  index_triggers_on_bot_id  (bot_id)
#
# Foreign Keys
#
#  bot_id  (bot_id => bots.id)
#
