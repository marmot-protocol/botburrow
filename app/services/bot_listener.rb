class BotListener
  AlreadyRunningError = Class.new(StandardError)

  GROUPS_REFRESH_INTERVAL = 30
  DEFAULT_LOCK_PATH = "tmp/pids/listener.lock"

  def initialize(wnd_class: Wnd::Client, sync_interval: 2, min_reply_delay: 1.0, lock_path: nil)
    @wnd_class = wnd_class
    @sync_interval = sync_interval
    @min_reply_delay = min_reply_delay
    @lock_path = lock_path || Rails.root.join(DEFAULT_LOCK_PATH)
    @running = true
    @threads = {}  # key: "bot_id:group_id", value: Thread
    @mutex = Mutex.new
  end

  def run
    acquire_lock!
    reconcile_stale_statuses

    while @running
      sync_bots
      record_heartbeat
      cleanup_dead_threads
      sleep @sync_interval
    end

    stop_all_threads
  ensure
    release_lock
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
    accept_pending_invites(bot) if bot.auto_accept_invitations?

    groups = fetch_bot_groups(bot)
    return if groups.empty?

    groups.each do |group_id|
      key = "#{bot.id}:#{group_id}"
      next if @mutex.synchronize { @threads[key]&.alive? }

      Rails.logger.info("[BotListener] Starting stream for bot #{bot.id} group #{group_id}")
      start_group_stream(bot, group_id, key)
    end
  end

  def accept_pending_invites(bot)
    wnd = @wnd_class.new
    invites = wnd.groups_invites(account: bot.npub)
    return unless invites.is_a?(Array) && invites.any?

    invites.each do |inv|
      group_id = extract_group_id_from_invite(inv)
      next unless group_id

      wnd.groups_accept(account: bot.npub, group_id: group_id)
      Rails.logger.info("[BotListener] Bot #{bot.id} auto-accepted invite to group #{group_id}")
    end
  rescue Wnd::Error => e
    Rails.logger.error("[BotListener] Failed to check/accept invites for bot #{bot.id}: #{e.message}")
  end

  def extract_group_id_from_invite(inv)
    mls_group_id = inv["mls_group_id"] || inv.dig("group", "mls_group_id")
    extract_group_id(mls_group_id)
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
    stream_started_at = Time.now.to_i

    thread = Thread.new do
      Rails.logger.info("[BotListener] Stream started for bot #{bot.id} group #{group_id}")
      wnd = @wnd_class.new(timeout: nil)
      wnd.messages_subscribe(account: bot.npub, group_id: group_id) do |event|
        handle_message_event(bot, group_id, event, stream_started_at)
      end
      Rails.logger.info("[BotListener] Stream ended for bot #{bot.id} group #{group_id}")
    rescue => e
      Rails.logger.error("[BotListener] Stream error for bot #{bot.id} group #{group_id}: #{e.class} - #{e.message}")
      sleep 5
      retry if @running
    end

    @mutex.synchronize { @threads[key] = thread }
  end

  def handle_message_event(bot, group_id, event, stream_started_at = 0)
    return unless event["trigger"] == "NewMessage"

    message = event["message"]
    return unless message

    message_time = message["created_at"].to_i
    return if message_time > 0 && message_time < stream_started_at

    content = message["content"]
    author = message["author"]

    return if author == bot.npub
    return unless content

    MessageDispatcher.new(bot, group_id, wnd_class: @wnd_class, min_reply_delay: @min_reply_delay).dispatch(content, author)
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
    Wnd.extract_group_id(mls_group_id)
  end

  def record_heartbeat
    Setting["listener.heartbeat"] = Time.current.iso8601
  end

  def acquire_lock!
    FileUtils.mkdir_p(File.dirname(@lock_path))
    @lock_file = File.open(@lock_path, File::CREAT | File::RDWR)
    unless @lock_file.flock(File::LOCK_EX | File::LOCK_NB)
      @lock_file.close
      raise AlreadyRunningError, "Another listener is already running (lock: #{@lock_path})"
    end
    @lock_file.puts(Process.pid)
    @lock_file.flush
  end

  def release_lock
    return unless @lock_file && !@lock_file.closed?
    @lock_file.flock(File::LOCK_UN)
    @lock_file.close
    @lock_file = nil
  end
end
