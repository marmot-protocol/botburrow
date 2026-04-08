class Bot < ApplicationRecord
  include ActionView::RecordIdentifier

  has_many :commands, dependent: :destroy
  has_many :triggers, dependent: :destroy
  has_many :scheduled_actions, dependent: :destroy
  has_many :message_logs, dependent: :delete_all

  enum :status, { stopped: 0, starting: 1, running: 2, stopping: 3, error: 4 }, default: :stopped

  validates :name, presence: true
  validates :npub, presence: true, uniqueness: true

  normalizes :name, with: -> { _1.strip }

  after_update_commit :broadcast_status_change, if: :saved_change_to_status?

  def display_npub
    Wnd::Nostr.to_npub(npub)
  rescue
    npub
  end

  private

  def broadcast_status_change
    broadcast_replace_to "bots"

    broadcast_replace_to self, target: dom_id(self, :status),
      partial: "bots/status_bar", locals: { bot: self }
    broadcast_replace_to self, target: dom_id(self, :status_detail),
      partial: "bots/status_detail", locals: { bot: self }
  rescue => e
    Rails.logger.warn("[Bot] Broadcast failed: #{e.message}")
  end
end

# == Schema Information
#
# Table name: bots
#
#  id                      :integer          not null, primary key
#  auto_accept_invitations :boolean          default(TRUE), not null
#  description             :text
#  error_message           :text
#  name                    :string           not null
#  npub                    :string           not null
#  picture_url             :string
#  script_data             :text             default("{}"), not null
#  status                  :integer          default("stopped"), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#
# Indexes
#
#  index_bots_on_npub  (npub) UNIQUE
#
