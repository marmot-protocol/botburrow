class Trigger < ApplicationRecord
  belongs_to :bot

  enum :condition_type, { keyword: 0, regex: 1, any: 2 }

  validates :name, presence: true
  validates :condition_value, presence: true, unless: -> { any? }
  validates :script_body, presence: true
  validate :script_body_syntax, if: -> { script_body.present? }

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

  private

  def script_body_syntax
    RubyVM::InstructionSequence.compile(script_body)
  rescue SyntaxError => e
    errors.add(:script_body, "has a syntax error: #{e.message}")
  end
end

# == Schema Information
#
# Table name: triggers
#
#  id              :integer          not null, primary key
#  condition_type  :integer          default("keyword"), not null
#  condition_value :string
#  enabled         :boolean          default(TRUE), not null
#  name            :string           not null
#  position        :integer
#  script_body     :text
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
