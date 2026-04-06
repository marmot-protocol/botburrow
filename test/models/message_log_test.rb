require "test_helper"

class MessageLogTest < ActiveSupport::TestCase
  setup do
    @bot = bots(:relay_bot)
  end

  # -- Slice 1: Validates required fields --

  test "valid message log with all required fields" do
    log = MessageLog.new(
      bot: @bot,
      group_id: "abc123",
      author: "npub1author",
      content: "Hello!",
      direction: "incoming",
      message_at: Time.current
    )
    assert log.valid?
  end

  test "requires group_id" do
    log = MessageLog.new(bot: @bot, author: "a", content: "c", direction: "incoming", message_at: Time.current)
    assert_not log.valid?
    assert_includes log.errors[:group_id], "can't be blank"
  end

  test "requires author" do
    log = MessageLog.new(bot: @bot, group_id: "g", content: "c", direction: "incoming", message_at: Time.current)
    assert_not log.valid?
    assert_includes log.errors[:author], "can't be blank"
  end

  test "requires content" do
    log = MessageLog.new(bot: @bot, group_id: "g", author: "a", direction: "incoming", message_at: Time.current)
    assert_not log.valid?
    assert_includes log.errors[:content], "can't be blank"
  end

  test "requires direction" do
    log = MessageLog.new(bot: @bot, group_id: "g", author: "a", content: "c", message_at: Time.current)
    assert_not log.valid?
    assert_includes log.errors[:direction], "can't be blank"
  end

  test "requires message_at" do
    log = MessageLog.new(bot: @bot, group_id: "g", author: "a", content: "c", direction: "incoming")
    assert_not log.valid?
    assert_includes log.errors[:message_at], "can't be blank"
  end

  test "belongs to bot" do
    log = MessageLog.new(group_id: "g", author: "a", content: "c", direction: "incoming", message_at: Time.current)
    assert_not log.valid?
    assert_includes log.errors[:bot], "must exist"
  end

  # -- Slice 2: Scopes --

  test "incoming scope returns only incoming messages" do
    @bot.message_logs.create!(group_id: "g", author: "a", content: "hi", direction: "incoming", message_at: 1.minute.ago)
    @bot.message_logs.create!(group_id: "g", author: "bot", content: "reply", direction: "outgoing", message_at: Time.current)

    incoming = @bot.message_logs.incoming
    assert_equal 1, incoming.count
    assert incoming.all? { |l| l.direction == "incoming" }
  end

  test "outgoing scope returns only outgoing messages" do
    @bot.message_logs.create!(group_id: "g", author: "a", content: "hi", direction: "incoming", message_at: 1.minute.ago)
    @bot.message_logs.create!(group_id: "g", author: "bot", content: "reply", direction: "outgoing", message_at: Time.current)

    outgoing = @bot.message_logs.outgoing
    assert_equal 1, outgoing.count
    assert outgoing.all? { |l| l.direction == "outgoing" }
  end

  test "recent scope orders by message_at descending" do
    old = @bot.message_logs.create!(group_id: "g", author: "a", content: "old", direction: "incoming", message_at: 2.hours.ago)
    new_log = @bot.message_logs.create!(group_id: "g", author: "a", content: "new", direction: "incoming", message_at: 1.minute.ago)

    recent = @bot.message_logs.recent
    assert_equal new_log.id, recent.first.id
    assert_equal old.id, recent.last.id
  end

  # -- Bot association --

  test "destroying bot deletes associated message logs" do
    bot = Bot.create!(name: "LogTest", npub: "npub1logtest#{SecureRandom.hex(20)}")
    bot.message_logs.create!(group_id: "g", author: "a", content: "hi", direction: "incoming", message_at: Time.current)

    assert_difference "MessageLog.count", -1 do
      bot.destroy
    end
  end
end

# == Schema Information
#
# Table name: message_logs
#
#  id         :integer          not null, primary key
#  author     :string           not null
#  content    :text             not null
#  direction  :string           not null
#  message_at :datetime         not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  bot_id     :integer          not null
#  group_id   :string           not null
#
# Indexes
#
#  index_message_logs_on_bot_id                 (bot_id)
#  index_message_logs_on_bot_id_and_group_id    (bot_id,group_id)
#  index_message_logs_on_bot_id_and_message_at  (bot_id,message_at)
#
# Foreign Keys
#
#  bot_id  (bot_id => bots.id)
#
