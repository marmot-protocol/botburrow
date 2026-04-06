class ExecuteScheduledActionsJob < ApplicationJob
  queue_as :default

  def perform(wnd_class: Wnd::Client)
    ScheduledAction.enabled.due.includes(:bot).find_each do |action|
      next unless action.bot.running?

      execute_action(action, wnd_class)
    rescue => e
      Rails.logger.error("[ScheduledActions] Failed to execute '#{action.name}' (id=#{action.id}): #{e.message}")
    end
  end

  private

  def execute_action(action, wnd_class)
    config = action.parsed_action_config
    group_id = config["group_id"]
    message = config["message"]

    if group_id.present? && message.present?
      wnd = wnd_class.new
      wnd.send_message(account: action.bot.npub, group_id: group_id, message: message)
      Rails.logger.info("[ScheduledActions] Sent message for '#{action.name}' to group #{group_id}")
    end

    action.last_run_at = Time.current
    action.compute_next_run
    action.save!
  end
end
