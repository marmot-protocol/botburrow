class MessageDispatcher
  def initialize(bot, group_id, wnd_class: Wnd::Client, min_reply_delay: 0)
    @bot = bot
    @group_id = group_id
    @wnd_class = wnd_class
    @min_reply_delay = min_reply_delay
    @received_at = Time.now.to_f
  end

  def dispatch(content, author)
    log_message(author, content, "incoming")

    commands = @bot.commands.enabled.to_a

    matched_command = commands.find { |c| c.matches?(content) }
    if matched_command
      response = resolve_command_response(matched_command, content, author)
      send_reply(response) if response.present?
      return
    end

    builtin_response = handle_builtin_command(commands, content)
    if builtin_response
      send_reply(builtin_response)
      return
    end

    triggers = @bot.triggers.enabled.order(:position).to_a
    matched_trigger = triggers.find { |t| t.matches?(content) }
    execute_trigger(matched_trigger, content: content, author: author) if matched_trigger
  end

  private

  def resolve_command_response(command, content, author)
    dispatch_script_command(command, content, author)
  end

  def handle_builtin_command(commands, content)
    normalized = content.strip.downcase

    if normalized == "/help"
      build_help_response(commands)
    elsif normalized == "/status"
      build_status_response(commands)
    end
  end

  def build_help_response(commands)
    lines = [ "#{@bot.name} - Available commands:" ]
    commands.each do |cmd|
      lines << "  #{cmd.pattern} - #{cmd.name}"
    end
    lines << "  /help - Show this help message"
    lines << "  /status - Show bot status"
    lines.join("\n")
  end

  def build_status_response(commands)
    uptime = @bot.created_at.present? ? "since #{@bot.created_at.to_fs(:short)}" : "unknown"
    "#{@bot.name} | Running #{uptime} | #{commands.size} command(s) enabled"
  end

  def dispatch_script_command(command, content, author)
    args_text = command.extract_args(content) || ""
    context = ScriptContext.new(
      bot: @bot, group_id: @group_id,
      author: author, message: content, args: args_text,
      sender: method(:send_reply)
    )
    ScriptRunner.execute(command.response_text, context, bot: @bot, group_id: @group_id)
  end

  def execute_trigger(trigger, content:, author:)
    context = ScriptContext.new(
      bot: @bot, group_id: @group_id,
      author: author, message: content, args: nil,
      sender: method(:send_reply)
    )
    response = ScriptRunner.execute(trigger.script_body, context, bot: @bot, group_id: @group_id)
    send_reply(response) if response.present?
  end

  def send_reply(message)
    ensure_min_delay
    wnd = @wnd_class.new
    wnd.send_message(account: @bot.npub, group_id: @group_id, message: message)
    log_message(@bot.npub, message, "outgoing")
  end

  def ensure_min_delay
    return if @min_reply_delay <= 0
    elapsed = Time.now.to_f - @received_at
    remaining = @min_reply_delay - elapsed
    sleep(remaining) if remaining > 0
  end

  def log_message(author, content, direction)
    @bot.message_logs.create!(
      group_id: @group_id,
      author: author,
      content: content,
      direction: direction,
      message_at: Time.current
    )
  rescue => e
    Rails.logger.error("[MessageDispatcher] Failed to log message: #{e.message}")
  end
end
