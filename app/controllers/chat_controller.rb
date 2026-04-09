class ChatController < ApplicationController
  include WndGroups

  before_action :set_bot

  def show
    @groups = fetch_bot_groups(@bot)
    @group_id = params[:group_id]

    if @group_id.present?
      @messages = @bot.message_logs.where(group_id: @group_id).order(:message_at).last(100)
      @author_names = resolve_author_names(@messages)
      @group_name = @groups.find { |g| g[:id] == @group_id }&.dig(:name) || @group_id.first(12)
    else
      @groups = enrich_groups_with_activity(@groups)
    end
  end

  def create
    wnd_client.send_message(account: @bot.npub, group_id: params[:group_id], message: params[:message])
    @bot.message_logs.create!(
      group_id: params[:group_id], author: @bot.npub,
      content: params[:message], direction: "outgoing", message_at: Time.current
    )
    redirect_to bot_chat_path(@bot, group_id: params[:group_id])
  end

  private

  def set_bot
    @bot = Bot.find(params[:bot_id])
  end

  def resolve_author_names(messages)
    pubkeys = messages.map(&:author).uniq - [@bot.npub]
    pubkeys.to_h { |pk| [pk, resolve_peer_name(pk)] }
  end

  def enrich_groups_with_activity(groups)
    active = groups.select { |g| g[:state] == "active" }
    group_ids = active.map { |g| g[:id] }

    counts = @bot.message_logs.where(group_id: group_ids).group(:group_id).count
    latest = @bot.message_logs.where(group_id: group_ids)
      .select("group_id, content, message_at")
      .where("message_at = (SELECT MAX(m2.message_at) FROM message_logs m2 WHERE m2.group_id = message_logs.group_id AND m2.bot_id = message_logs.bot_id)")

    latest_by_group = latest.index_by(&:group_id)

    active.each do |group|
      group[:message_count] = counts[group[:id]] || 0
      last = latest_by_group[group[:id]]
      group[:last_message] = last&.content&.truncate(50)
      group[:last_message_at] = last&.message_at
    end
    active.sort_by { |g| g[:last_message_at] || Time.at(0) }.reverse
  end
end
