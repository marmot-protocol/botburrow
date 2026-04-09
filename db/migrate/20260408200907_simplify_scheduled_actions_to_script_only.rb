class SimplifyScheduledActionsToScriptOnly < ActiveRecord::Migration[8.1]
  def up
    add_column :scheduled_actions, :group_id, :string

    # Extract group_id from action_config JSON
    execute <<~SQL
      UPDATE scheduled_actions
      SET group_id = json_extract(action_config, '$.group_id')
      WHERE action_config IS NOT NULL
        AND json_extract(action_config, '$.group_id') IS NOT NULL
    SQL

    # Convert send_message actions to script_body
    execute <<~SQL
      UPDATE scheduled_actions
      SET script_body = '"' || REPLACE(
        json_extract(action_config, '$.message'),
        '"', '\"'
      ) || '"'
      WHERE action_type = 0
        AND script_body IS NULL
        AND action_config IS NOT NULL
        AND json_extract(action_config, '$.message') IS NOT NULL
    SQL

    # Any remaining without script_body get nil default
    execute <<~SQL
      UPDATE scheduled_actions
      SET script_body = 'nil'
      WHERE script_body IS NULL
    SQL

    remove_column :scheduled_actions, :action_type
    remove_column :scheduled_actions, :action_config
  end

  def down
    add_column :scheduled_actions, :action_type, :integer, default: 0, null: false
    add_column :scheduled_actions, :action_config, :text, null: false, default: "{}"
    remove_column :scheduled_actions, :group_id
  end
end
