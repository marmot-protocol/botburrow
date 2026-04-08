class ScriptRunner
  def self.execute(body, context, bot:, group_id:)
    threads_before = Thread.list

    result = context.instance_eval(body)
    context.store.save!
    result.is_a?(String) ? result : nil
  rescue SystemExit
    log_script_error(bot, group_id, RuntimeError.new("Script called exit"))
    nil
  rescue NoMemoryError
    log_script_error(bot, group_id, RuntimeError.new("Script used too much memory"))
    nil
  rescue SystemStackError
    log_script_error(bot, group_id, RuntimeError.new("Script has infinite recursion (stack overflow)"))
    nil
  rescue ScriptError, StandardError => e
    log_script_error(bot, group_id, e)
    nil
  ensure
    cleanup_threads(threads_before)
  end

  def self.cleanup_threads(threads_before)
    spawned = Thread.list - threads_before
    return if spawned.empty?

    Rails.logger.warn("[ScriptRunner] Killing #{spawned.size} thread(s) leaked by script")
    spawned.each { |t| t.kill rescue nil }
  end

  def self.log_script_error(bot, group_id, error)
    line_info = extract_eval_line(error)
    message = if line_info
      "Script error (line #{line_info}): #{error.class}: #{error.message}"
    else
      "Script error: #{error.class}: #{error.message}"
    end

    Rails.logger.error("[ScriptRunner] #{message}")
    if error.backtrace
      error.backtrace.first(5).each { |line| Rails.logger.error("  #{line}") }
    end

    return unless bot && group_id
    MessageLog.create(
      bot: bot,
      group_id: group_id,
      author: "system",
      content: message.truncate(500),
      direction: "error",
      message_at: Time.current
    )
  rescue => e
    Rails.logger.error("[ScriptRunner] Failed to log error: #{e.message}")
  end

  def self.extract_eval_line(error)
    return unless error.backtrace
    # Ruby >= 3.3: "(eval at /path/file.rb:53):3:in '<main>'"
    # Ruby < 3.3:  "(eval):3:in `block in ...'"
    match = error.backtrace.find { |l| l.include?("(eval") }
    match&.match(/\(eval[^)]*\):(\d+)/)&.captures&.first
  end
end
