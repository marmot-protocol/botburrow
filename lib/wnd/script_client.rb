module Wnd
  class ScriptClient
    def initialize(client, account:)
      @client = client
      @account = account
    end

    def groups              = @client.groups_list(account: @account)
    def invites             = @client.groups_invites(account: @account)
    def profile             = @client.profile_show(account: @account)
    def user(pubkey)        = @client.users_show(pubkey: pubkey)
    def members(group_id)   = @client.group_members(account: @account, group_id: group_id)

    def accept_invite(group_id)  = @client.groups_accept(account: @account, group_id: group_id)
    def decline_invite(group_id) = @client.groups_decline(account: @account, group_id: group_id)
  end
end
