class MessageLogsController < ApplicationController
  include WndGroups

  before_action :set_bot

  def index
    @groups = fetch_bot_groups(@bot)
    @logs = @bot.message_logs.recent
    @logs = @logs.where(group_id: params[:group_id]) if params[:group_id].present?
    @logs = @logs.where(direction: params[:direction]) if params[:direction].present?
    @logs = @logs.limit(100)
  end

  private

  def set_bot
    @bot = Bot.find(params[:bot_id])
  end
end
