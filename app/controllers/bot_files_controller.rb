class BotFilesController < ApplicationController
  before_action :set_bot

  def create
    script_files = ScriptFiles.new(@bot)
    uploaded = params[:file]

    if uploaded.blank?
      redirect_to bot_path(@bot, anchor: "files"), alert: "No file selected."
      return
    end

    if uploaded.size > ScriptFiles::MAX_FILE_SIZE
      redirect_to bot_path(@bot, anchor: "files"), alert: "File exceeds #{ScriptFiles::MAX_FILE_SIZE / 1.megabyte} MB limit."
      return
    end

    filename = sanitize_filename(uploaded.original_filename)
    script_files.write(filename, uploaded.read)
    redirect_to bot_path(@bot, anchor: "files"), notice: "#{filename} uploaded."
  rescue ScriptFiles::QuotaExceeded => e
    redirect_to bot_path(@bot, anchor: "files"), alert: e.message
  end

  def download
    script_files = ScriptFiles.new(@bot)
    full_path = script_files.safe_path(params[:path])
    raise ActiveRecord::RecordNotFound unless File.file?(full_path)

    send_file full_path, filename: File.basename(full_path), disposition: :attachment
  rescue ScriptFiles::SandboxError
    raise ActiveRecord::RecordNotFound
  end

  def destroy
    script_files = ScriptFiles.new(@bot)

    if script_files.delete(params[:path])
      redirect_to bot_path(@bot, anchor: "files"), notice: "File deleted."
    else
      redirect_to bot_path(@bot, anchor: "files"), alert: "File not found."
    end
  rescue ScriptFiles::SandboxError
    redirect_to bot_path(@bot, anchor: "files"), alert: "Invalid file path."
  end

  private

  def set_bot
    @bot = Bot.find(params[:bot_id])
  end

  def sanitize_filename(name)
    name = File.basename(name.to_s)
    name = name.gsub(/[^\w.\-]/, "_")
    name = name.sub(/\A\.+/, "")
    name = "unnamed" if name.blank?
    name.truncate(255, omission: "")
  end
end
