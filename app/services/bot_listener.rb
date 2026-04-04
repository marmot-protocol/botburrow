class BotListener
  GROUPS_REFRESH_INTERVAL = 30

  def initialize(wnd_class: Wnd::Client, sync_interval: 2)
    @wnd_class = wnd_class
    @sync_interval = sync_interval
    @running = true
    @threads = {}  # key: "bot_id:group_id", value: Thread
    @mutex = Mutex.new
  end

  def run
    reconcile_stale_statuses

    while @running
      sync_bots
      record_heartbeat
      cleanup_dead_threads
      sleep @sync_interval
    end

    stop_all_threads
  end

  def shutdown
    @running = false
  end

  private

  def reconcile_stale_statuses
    Bot.where(status: [ :starting, :running ]).find_each do |bot|
      bot.update!(status: :stopped, error_message: nil)
    end
  end

  def sync_bots
    Bot.where(status: :starting).find_each do |bot|
      start_bot(bot)
    end

    Bot.where(status: :stopping).find_each do |bot|
      stop_bot(bot)
    end

    # Refresh group subscriptions for running bots
    Bot.where(status: :running).find_each do |bot|
      ensure_group_streams(bot)
    end
  end

  def start_bot(bot)
    bot.update!(status: :running)
    Rails.logger.info("[BotListener] Bot #{bot.id} (#{bot.name}) is now running")
    ensure_group_streams(bot)
  end

  def stop_bot(bot)
    # Kill all threads for this bot
    @mutex.synchronize do
      @threads.each do |key, thread|
        if key.start_with?("#{bot.id}:")
          thread.kill
          thread.join(2)
          @threads.delete(key)
        end
      end
    end
    bot.update!(status: :stopped)
    Rails.logger.info("[BotListener] Bot #{bot.id} (#{bot.name}) stopped")
  end

  def ensure_group_streams(bot)
    groups = fetch_bot_groups(bot)
    return if groups.empty?

    groups.each do |group_id|
      key = "#{bot.id}:#{group_id}"
      next if @mutex.synchronize { @threads[key]&.alive? }

      start_group_stream(bot, group_id, key)
    end
  end

  def fetch_bot_groups(bot)
    wnd = @wnd_class.new
    result = wnd.groups_list(account: bot.npub)
    return [] unless result.is_a?(Array)

    result.filter_map do |entry|
      group = entry["group"]
      next unless group && group["state"] == "active"
      extract_group_id(group["mls_group_id"])
    end
  rescue Wnd::Error => e
    Rails.logger.error("[BotListener] Failed to list groups for bot #{bot.id}: #{e.message}")
    []
  end

  def start_group_stream(bot, group_id, key)
    commands = bot.commands.enabled.to_a

    thread = Thread.new do
      wnd = @wnd_class.new(timeout: nil)
      wnd.messages_subscribe(account: bot.npub, group_id: group_id, limit: 0) do |event|
        handle_message_event(bot, commands, group_id, event)
      end
    rescue => e
      Rails.logger.error("[BotListener] Stream error for bot #{bot.id} group #{group_id}: #{e.class} - #{e.message}")
      sleep 5
      retry if @running
    end

    @mutex.synchronize { @threads[key] = thread }
  end

  def handle_message_event(bot, commands, group_id, event)
    trigger = event["trigger"]
    return unless trigger == "NewMessage"

    message = event["message"]
    return unless message

    content = message["content"]
    author = message["author"]

    return if author == bot.npub
    return unless content

    matched = commands.find { |c| c.matches?(content) }
    return unless matched

    wnd = @wnd_class.new
    wnd.send_message(account: bot.npub, group_id: group_id, message: matched.response_text)
    Rails.logger.info("[BotListener] Bot #{bot.id} matched '#{matched.name}' in group #{group_id}")
  rescue Wnd::Error => e
    Rails.logger.error("[BotListener] Failed to send reply: #{e.message}")
  end

  def cleanup_dead_threads
    @mutex.synchronize do
      @threads.delete_if { |_, thread| !thread.alive? }
    end
  end

  def stop_all_threads
    @mutex.synchronize do
      @threads.each_value do |thread|
        thread.kill
        thread.join(2)
      end
      @threads.clear
    end
  end

  def extract_group_id(mls_group_id)
    return mls_group_id if mls_group_id.is_a?(String)
    return unless mls_group_id.is_a?(Hash)

    bytes = mls_group_id.dig("value", "vec")
    return unless bytes.is_a?(Array)

    bytes.pack("C*").unpack1("H*")
  end

  def record_heartbeat
    Setting["listener.heartbeat"] = Time.current.iso8601
  end
end
