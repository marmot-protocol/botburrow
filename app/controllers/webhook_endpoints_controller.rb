class WebhookEndpointsController < ApplicationController
  before_action :set_bot
  before_action :set_webhook_endpoint, only: %i[edit update destroy]

  def index
    @webhook_endpoints = @bot.webhook_endpoints.order(created_at: :desc)
  end

  def new
    @webhook_endpoint = @bot.webhook_endpoints.build(enabled: true)
  end

  def create
    @webhook_endpoint = @bot.webhook_endpoints.build(webhook_endpoint_params)

    if @webhook_endpoint.save
      redirect_to @bot, notice: "Webhook endpoint was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @webhook_endpoint.update(webhook_endpoint_params)
      redirect_to @bot, notice: "Webhook endpoint was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @webhook_endpoint.destroy
    redirect_to @bot, notice: "Webhook endpoint was successfully deleted.", status: :see_other
  end

  private

  def set_bot
    @bot = Bot.find(params[:bot_id])
  end

  def set_webhook_endpoint
    @webhook_endpoint = @bot.webhook_endpoints.find(params[:id])
  end

  def webhook_endpoint_params
    params.expect(webhook_endpoint: [ :name, :url, :secret, :enabled ])
  end
end
