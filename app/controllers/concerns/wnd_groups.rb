module WndGroups
  extend ActiveSupport::Concern

  included do
    class_attribute :wnd_client_class, default: Wnd::Client
  end

  private

  def wnd_client
    self.class.wnd_client_class.new
  end

  def fetch_bot_groups(bot)
    result = wnd_client.groups_list(account: bot.npub)
    return [] unless result.is_a?(Array)

    result.map do |entry|
      group = entry["group"]
      membership = entry["membership"] || {}
      {
        id: extract_group_id(group["mls_group_id"]),
        name: resolve_group_name(group, membership),
        state: group["state"],
        members: group["admin_pubkeys"]&.size || 0
      }
    end
  rescue Wnd::Error => e
    Rails.logger.error("[#{self.class.name}] Failed to fetch groups: #{e.message}")
    []
  end

  def resolve_group_name(group, membership)
    return group["name"] if group["name"].present?

    if (peer = membership["dm_peer_pubkey"]).present?
      resolve_peer_name(peer)
    else
      "(unnamed)"
    end
  end

  def resolve_peer_name(pubkey)
    user = wnd_client.users_show(pubkey: pubkey)
    meta = user["metadata"] || {}

    meta["display_name"].presence || meta["name"].presence ||
      "#{Wnd::Nostr.to_npub(pubkey).first(16)}..."
  rescue Wnd::Error
    "#{Wnd::Nostr.to_npub(pubkey).first(16)}..."
  end

  def extract_group_id(mls_group_id)
    Wnd.extract_group_id(mls_group_id)
  end
end
