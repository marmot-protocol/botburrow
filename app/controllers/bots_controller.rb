class BotsController < ApplicationController
  class_attribute :wnd_client_class, default: Wnd::Client

  before_action :set_bot, only: %i[show edit update destroy start stop]

  def index
    @bots = Bot.order(created_at: :desc)
  end

  def show
  end

  def new
    @bot = Bot.new(auto_accept_invitations: true)
  end

  def create
    wnd = wnd_client
    result = wnd.create_identity
    npub = result["pubkey"]
    wnd.keys_publish(account: npub)
    wnd.profile_update(account: npub, name: bot_params[:name], about: bot_params[:description])

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
      wnd_client.profile_update(account: @bot.npub, name: @bot.name, about: @bot.description)
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

  private

  def set_bot
    @bot = Bot.find(params[:id])
  end

  def bot_params
    params.expect(bot: [ :name, :description, :auto_accept_invitations ])
  end

  def wnd_client
    self.class.wnd_client_class.new
  end
end
