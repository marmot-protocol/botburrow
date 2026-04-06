class ScheduledAction < ApplicationRecord
  belongs_to :bot

  enum :action_type, { send_message: 0 }

  validates :name, presence: true
  validates :schedule, presence: true,
    format: { with: /\Aevery \d+[mhd]\z/, message: "must be like 'every 30m', 'every 1h', or 'every 1d'" }
  validates :action_config, presence: true

  before_save :compute_next_run, if: -> { schedule_changed? || next_run_at.nil? }

  normalizes :name, with: -> { _1.strip }

  scope :enabled, -> { where(enabled: true) }
  scope :due, -> { where("next_run_at <= ?", Time.current) }

  def parsed_action_config
    JSON.parse(action_config)
  rescue JSON::ParserError
    {}
  end

  def compute_next_run
    interval = parse_interval(schedule)
    self.next_run_at = (last_run_at || Time.current) + interval
  end

  private

  def parse_interval(schedule_str)
    amount, unit = schedule_str.match(/\Aevery (\d+)([mhd])\z/).captures
    case unit
    when "m" then amount.to_i.minutes
    when "h" then amount.to_i.hours
    when "d" then amount.to_i.days
    end
  end
end

# == Schema Information
#
# Table name: scheduled_actions
#
#  id            :integer          not null, primary key
#  action_config :text             not null
#  action_type   :integer          default("send_message"), not null
#  enabled       :boolean          default(TRUE), not null
#  last_run_at   :datetime
#  name          :string           not null
#  next_run_at   :datetime
#  schedule      :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  bot_id        :integer          not null
#
# Indexes
#
#  index_scheduled_actions_on_bot_id  (bot_id)
#
# Foreign Keys
#
#  bot_id  (bot_id => bots.id)
#
