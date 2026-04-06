class Bot < ApplicationRecord
  has_many :commands, dependent: :destroy
  has_many :triggers, dependent: :destroy
  has_many :scheduled_actions, dependent: :destroy
  has_many :webhook_endpoints, dependent: :destroy
  has_many :message_logs, dependent: :delete_all

  enum :status, { stopped: 0, starting: 1, running: 2, stopping: 3, error: 4 }, default: :stopped

  validates :name, presence: true
  validates :npub, presence: true, uniqueness: true

  normalizes :name, with: -> { _1.strip }

  after_update_commit -> { broadcast_replace_to "bots" rescue nil }, if: :saved_change_to_status?

  def display_npub
    Wnd::Nostr.to_npub(npub)
  rescue
    npub
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
#  status                  :integer          default("stopped"), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#
# Indexes
#
#  index_bots_on_npub  (npub) UNIQUE
#
