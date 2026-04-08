class ScriptStore
  def initialize(bot)
    @bot = bot
    @data = JSON.parse(bot.script_data.presence || "{}")
    @dirty = false
  rescue JSON::ParserError
    Rails.logger.error("[ScriptStore] Corrupt script_data for bot #{bot.id}, resetting")
    @data = {}
    @dirty = true
  end

  def [](key) = @data[key.to_s]

  def []=(key, value)
    @data[key.to_s] = value
    @dirty = true
  end

  def delete(key)
    @data.delete(key.to_s)
    @dirty = true
  end

  def keys = @data.keys

  def save!
    return unless @dirty
    @bot.update!(script_data: @data.to_json)
  end
end
