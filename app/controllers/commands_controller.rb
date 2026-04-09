class CommandsController < ApplicationController
  before_action :set_bot
  before_action :set_command, only: %i[edit update destroy toggle_enabled]

  def new
    @command = @bot.commands.build(enabled: true)
  end

  def create
    @command = @bot.commands.build(command_params)

    if @command.save
      redirect_to bot_path(@bot, anchor: "commands"), notice: "Command was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @command.update(command_params)
      redirect_to bot_path(@bot, anchor: "commands"), notice: "Command was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def toggle_enabled
    @command.update!(enabled: !@command.enabled?)
    render_toggle(@command, toggle_enabled_bot_command_path(@bot, @command))
  end

  def destroy
    @command.destroy
    redirect_to bot_path(@bot, anchor: "commands"), notice: "Command was successfully deleted.", status: :see_other
  end

  private

  def set_bot
    @bot = Bot.find(params[:bot_id])
  end

  def set_command
    @command = @bot.commands.find(params[:id])
  end

  def command_params
    params.expect(command: [ :name, :pattern, :response_text, :enabled ])
  end
end
