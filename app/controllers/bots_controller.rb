class BotsController < ApplicationController
  include WndGroups

  before_action :set_bot, only: %i[show edit update destroy start stop accept_invitation decline_invitation]

  def index
    @bots = Bot.order(created_at: :desc)
  end

  def show
    sync_profile_picture(@bot)
    @groups = fetch_bot_groups(@bot)
    @invitations = fetch_bot_invitations unless @bot.auto_accept_invitations?
    @logs = @bot.message_logs.recent.limit(100)

    script_files = ScriptFiles.new(@bot)
    @tree = script_files.tree
    @total_usage = script_files.total_usage
  end

  def new
    @bot = Bot.new(auto_accept_invitations: true)
  end

  def create
    wnd = wnd_client
    result = wnd.create_identity
    npub = result["pubkey"]
    wnd.keys_publish(account: npub)
    wnd.profile_update(account: npub, name: bot_params[:name], about: bot_params[:description], picture: bot_params[:picture_url].presence)

    @bot = Bot.new(bot_params.merge(npub: npub))

    if @bot.save
      redirect_to @bot, notice: "Bot was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  rescue Wnd::Error => e
    @bot = Bot.new(bot_params)
    @bot.errors.add(:base, "Could not create identity: #{e.message}")
    render :new, status: :unprocessable_entity
  end

  def edit
  end

  def update
    if @bot.update(bot_params)
      wnd_client.profile_update(account: @bot.npub, name: @bot.name, about: @bot.description, picture: @bot.picture_url.presence)
      redirect_to @bot, notice: "Bot was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  rescue Wnd::Error
    redirect_to @bot, notice: "Bot updated, but profile sync failed."
  end

  def destroy
    @bot.stopping!
    begin
      wnd_client.accounts_list
    rescue Wnd::Error
      # wnd unavailable during destroy is acceptable
    end
    @bot.destroy
    redirect_to bots_path, notice: "Bot was successfully deleted.", status: :see_other
  end

  def start
    @bot.starting!
    redirect_to @bot, notice: "Bot is starting."
  end

  def stop
    @bot.stopping!
    redirect_to @bot, notice: "Bot is stopping."
  end

  def accept_invitation
    wnd_client.groups_accept(account: @bot.npub, group_id: params[:group_id])
    redirect_to @bot, notice: "Invitation accepted."
  rescue Wnd::Error => e
    redirect_to @bot, alert: "Failed to accept: #{e.message}"
  end

  def decline_invitation
    wnd_client.groups_decline(account: @bot.npub, group_id: params[:group_id])
    redirect_to @bot, notice: "Invitation declined."
  rescue Wnd::Error => e
    redirect_to @bot, alert: "Failed to decline: #{e.message}"
  end

  private

  def set_bot
    @bot = Bot.find(params[:id])
  end

  def bot_params
    params.expect(bot: [ :name, :description, :auto_accept_invitations, :picture_url ])
  end

  def fetch_bot_invitations
    result = wnd_client.groups_invites(account: @bot.npub)
    return [] unless result.is_a?(Array)

    result.map do |entry|
      group = entry["group"]
      membership = entry["membership"] || {}
      {
        id: extract_group_id(group["mls_group_id"]),
        name: resolve_group_name(group, membership)
      }
    end
  rescue Wnd::Error => e
    Rails.logger.error("[BotsController] Failed to fetch invitations: #{e.message}")
    []
  end

  def sync_profile_picture(bot)
    profile = wnd_client.profile_show(account: bot.npub)
    picture = profile["picture"]&.to_s.presence
    bot.update_column(:picture_url, picture) if bot.picture_url != picture
  rescue Wnd::Error
    # wnd unavailable — show what we have cached
  end
end
