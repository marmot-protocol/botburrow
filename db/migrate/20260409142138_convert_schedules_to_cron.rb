class ConvertSchedulesToCron < ActiveRecord::Migration[8.1]
  def up
    execute("SELECT id, schedule FROM scheduled_actions").each do |row|
      cron = convert_to_cron(row["schedule"])
      next unless cron

      execute("UPDATE scheduled_actions SET schedule = #{quote(cron)} WHERE id = #{row['id']}")
    end
  end

  def down
    # One-way migration — cron is more expressive than the old format
  end

  private

  def convert_to_cron(schedule)
    match = schedule.match(/\Aevery (\d+)([mhd])\z/)
    return nil unless match

    amount, unit = match.captures
    n = amount.to_i

    case unit
    when "m" then n == 1 ? "* * * * *" : "*/#{n} * * * *"
    when "h" then n == 1 ? "0 * * * *" : "0 */#{n} * * *"
    when "d" then n == 1 ? "0 0 * * *" : "0 0 */#{n} * *"
    end
  end
end
