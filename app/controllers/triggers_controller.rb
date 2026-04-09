class TriggersController < ApplicationController
  before_action :set_bot
  before_action :set_trigger, only: %i[edit update destroy toggle_enabled]

  def index
    @triggers = @bot.triggers.order(:position)
  end

  def new
    @trigger = @bot.triggers.build(enabled: true)
  end

  def create
    @trigger = @bot.triggers.build(trigger_params)

    if @trigger.save
      redirect_to bot_path(@bot, anchor: "triggers"), notice: "Trigger was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @trigger.update(trigger_params)
      redirect_to bot_path(@bot, anchor: "triggers"), notice: "Trigger was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def toggle_enabled
    @trigger.update!(enabled: !@trigger.enabled?)
    render_toggle(@trigger, toggle_enabled_bot_trigger_path(@bot, @trigger))
  end

  def destroy
    @trigger.destroy
    redirect_to bot_path(@bot, anchor: "triggers"), notice: "Trigger was successfully deleted.", status: :see_other
  end

  private

  def set_bot
    @bot = Bot.find(params[:bot_id])
  end

  def set_trigger
    @trigger = @bot.triggers.find(params[:id])
  end

  def trigger_params
    params.expect(trigger: [ :name, :condition_type, :condition_value,
                             :script_body, :position, :enabled ])
  end
end
