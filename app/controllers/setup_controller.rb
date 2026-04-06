class SetupController < ApplicationController
  layout "auth"
  allow_unauthenticated_access

  before_action :require_no_users

  def new
    @user = User.new
  end

  def create
    @user = User.new(setup_params)

    if @user.save
      start_new_session_for @user
      redirect_to root_path, notice: "Welcome to Botburrow!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def setup_params
    params.expect(user: [ :email_address, :password, :password_confirmation ])
  end

  def require_no_users
    redirect_to root_path if User.exists?
  end
end
