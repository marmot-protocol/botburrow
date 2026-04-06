class CleanupMessageLogsJob < ApplicationJob
  queue_as :default

  def perform(retention_days: 30)
    cutoff = retention_days.days.ago
    deleted = MessageLog.where(message_at: ...cutoff).delete_all
    Rails.logger.info("[CleanupMessageLogs] Deleted #{deleted} message logs older than #{retention_days} days")
  end
end
