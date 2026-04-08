class ScheduledActionsController < ApplicationController
  before_action :set_bot
  before_action :set_scheduled_action, only: %i[edit update destroy]

  def index
    @scheduled_actions = @bot.scheduled_actions.order(:name)
  end

  def new
    @scheduled_action = @bot.scheduled_actions.build(enabled: true)
  end

  def create
    @scheduled_action = @bot.scheduled_actions.build(scheduled_action_params)

    if @scheduled_action.save
      redirect_to @bot, notice: "Scheduled action was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @scheduled_action.update(scheduled_action_params)
      redirect_to @bot, notice: "Scheduled action was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @scheduled_action.destroy
    redirect_to @bot, notice: "Scheduled action was successfully deleted.", status: :see_other
  end

  private

  def set_bot
    @bot = Bot.find(params[:bot_id])
  end

  def set_scheduled_action
    @scheduled_action = @bot.scheduled_actions.find(params[:id])
  end

  def scheduled_action_params
    params.expect(scheduled_action: [ :name, :schedule, :action_type, :action_config, :script_body, :enabled ])
  end
end
