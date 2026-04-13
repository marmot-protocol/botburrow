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
    Array(action.group_ids).each do |group_id|
      execute_in_group(action, group_id, wnd_class)
    end

    action.last_run_at = Time.current
    action.compute_next_run
    action.save!
  end

  def execute_in_group(action, group_id, wnd_class)
    wnd = wnd_class.new
    sender = ->(text) {
      wnd.send_message(account: action.bot.npub, group_id: group_id, message: text)
      action.bot.message_logs.create!(
        group_id: group_id, author: action.bot.npub,
        content: text, direction: "outgoing", message_at: Time.current
      )
    }
    script_wnd = Wnd::ScriptClient.new(wnd, account: action.bot.npub)
    context = ScriptContext.new(
      bot: action.bot, group_id: group_id,
      author: nil, message: nil, args: nil,
      sender: sender,
      wnd: script_wnd
    )
    response = ScriptRunner.execute(action.script_body, context, bot: action.bot, group_id: group_id)
    sender.call(response) if response.present?
  end
end
