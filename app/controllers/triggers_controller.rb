class TriggersController < ApplicationController
  before_action :set_bot
  before_action :set_trigger, only: %i[edit update destroy]

  def index
    @triggers = @bot.triggers.order(:position)
  end

  def new
    @trigger = @bot.triggers.build(enabled: true)
  end

  def create
    @trigger = @bot.triggers.build(trigger_params)

    if @trigger.save
      redirect_to @bot, notice: "Trigger was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @trigger.update(trigger_params)
      redirect_to @bot, notice: "Trigger was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @trigger.destroy
    redirect_to @bot, notice: "Trigger was successfully deleted.", status: :see_other
  end

  private

  def set_bot
    @bot = Bot.find(params[:bot_id])
  end

  def set_trigger
    @trigger = @bot.triggers.find(params[:id])
  end

  def trigger_params
    params.expect(trigger: [ :name, :event_type, :condition_type, :condition_value,
                             :action_type, :action_config, :position, :enabled ])
  end
end
