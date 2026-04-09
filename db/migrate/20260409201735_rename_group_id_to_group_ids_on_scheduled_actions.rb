class RenameGroupIdToGroupIdsOnScheduledActions < ActiveRecord::Migration[8.1]
  def up
    rename_column :scheduled_actions, :group_id, :group_ids

    # Convert existing single group_id strings to JSON arrays
    execute("SELECT id, group_ids FROM scheduled_actions").each do |row|
      value = row["group_ids"]
      next if value.blank?
      next if value.start_with?("[")

      execute("UPDATE scheduled_actions SET group_ids = #{quote([value].to_json)} WHERE id = #{row['id']}")
    end
  end

  def down
    # Convert JSON arrays back to single strings
    execute("SELECT id, group_ids FROM scheduled_actions").each do |row|
      value = row["group_ids"]
      next if value.blank?

      first_id = (JSON.parse(value).first rescue value)
      execute("UPDATE scheduled_actions SET group_ids = #{quote(first_id)} WHERE id = #{row['id']}")
    end

    rename_column :scheduled_actions, :group_ids, :group_id
  end
end
