class ScheduledActionsController < ApplicationController
  include WndGroups

  before_action :set_bot
  before_action :set_scheduled_action, only: %i[edit update destroy toggle_enabled]
  before_action :load_groups, only: %i[new create edit update]

  def index
    @scheduled_actions = @bot.scheduled_actions.order(:name)
  end

  def new
    @scheduled_action = @bot.scheduled_actions.build(enabled: true)
  end

  def create
    @scheduled_action = @bot.scheduled_actions.build(scheduled_action_params)

    if @scheduled_action.save
      redirect_to bot_path(@bot, anchor: "schedules"), notice: "Scheduled action was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @scheduled_action.update(scheduled_action_params)
      redirect_to bot_path(@bot, anchor: "schedules"), notice: "Scheduled action was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def toggle_enabled
    @scheduled_action.update!(enabled: !@scheduled_action.enabled?)
    render_toggle(@scheduled_action, toggle_enabled_bot_scheduled_action_path(@bot, @scheduled_action))
  end

  def destroy
    @scheduled_action.destroy
    redirect_to bot_path(@bot, anchor: "schedules"), notice: "Scheduled action was successfully deleted.", status: :see_other
  end

  private

  def set_bot
    @bot = Bot.find(params[:bot_id])
  end

  def set_scheduled_action
    @scheduled_action = @bot.scheduled_actions.find(params[:id])
  end

  def load_groups
    @groups = fetch_bot_groups(@bot)
  end

  def scheduled_action_params
    permitted = params.require(:scheduled_action).permit(:name, :schedule, :script_body, :enabled, group_ids: [])
    permitted[:group_ids] = permitted[:group_ids]&.reject(&:blank?) if permitted.key?(:group_ids)
    permitted
  end
end
