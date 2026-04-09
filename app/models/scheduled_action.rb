class ScheduledAction < ApplicationRecord
  belongs_to :bot

  serialize :group_ids, coder: JSON

  validates :name, presence: true
  validates :schedule, presence: true
  validates :group_ids, presence: true
  validates :script_body, presence: true
  validate :schedule_is_valid_cron
  validate :script_body_syntax, if: -> { script_body.present? }

  before_save :compute_next_run, if: -> { schedule_changed? || next_run_at.nil? }

  normalizes :name, with: -> { _1.strip }

  scope :enabled, -> { where(enabled: true) }
  scope :due, -> { where("next_run_at <= ?", Time.current) }

  def compute_next_run
    cron = Fugit::Cron.parse(schedule)
    self.next_run_at = cron.next_time.to_t if cron
  end

  private

  def schedule_is_valid_cron
    return if schedule.blank?
    errors.add(:schedule, "is not a valid cron expression") unless Fugit::Cron.parse(schedule)
  end

  def script_body_syntax
    RubyVM::InstructionSequence.compile(script_body)
  rescue SyntaxError => e
    errors.add(:script_body, "has a syntax error: #{e.message}")
  end
end

# == Schema Information
#
# Table name: scheduled_actions
#
#  id          :integer          not null, primary key
#  enabled     :boolean          default(TRUE), not null
#  group_ids   :string
#  last_run_at :datetime
#  name        :string           not null
#  next_run_at :datetime
#  schedule    :string           not null
#  script_body :text
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  bot_id      :integer          not null
#
# Indexes
#
#  index_scheduled_actions_on_bot_id  (bot_id)
#
# Foreign Keys
#
#  bot_id  (bot_id => bots.id)
#
