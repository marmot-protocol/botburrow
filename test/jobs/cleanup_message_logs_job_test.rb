require "test_helper"

class CleanupMessageLogsJobTest < ActiveSupport::TestCase
  setup do
    @bot = bots(:relay_bot)
  end

  test "deletes message logs older than 30 days by default" do
    old = @bot.message_logs.create!(
      group_id: "g", author: "a", content: "old", direction: "incoming",
      message_at: 31.days.ago
    )
    recent = @bot.message_logs.create!(
      group_id: "g", author: "a", content: "new", direction: "incoming",
      message_at: 1.day.ago
    )

    CleanupMessageLogsJob.new.perform

    assert_not MessageLog.exists?(old.id)
    assert MessageLog.exists?(recent.id)
  end

  test "respects custom retention days" do
    old_7 = @bot.message_logs.create!(
      group_id: "g", author: "a", content: "old7", direction: "incoming",
      message_at: 8.days.ago
    )
    recent_7 = @bot.message_logs.create!(
      group_id: "g", author: "a", content: "recent7", direction: "incoming",
      message_at: 5.days.ago
    )

    CleanupMessageLogsJob.new.perform(retention_days: 7)

    assert_not MessageLog.exists?(old_7.id)
    assert MessageLog.exists?(recent_7.id)
  end

  test "does nothing when no old logs exist" do
    recent = @bot.message_logs.create!(
      group_id: "g", author: "a", content: "fresh", direction: "incoming",
      message_at: 1.hour.ago
    )

    assert_no_difference "MessageLog.count" do
      CleanupMessageLogsJob.new.perform
    end

    assert MessageLog.exists?(recent.id)
  end
end
