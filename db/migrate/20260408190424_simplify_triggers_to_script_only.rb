class SimplifyTriggersToScriptOnly < ActiveRecord::Migration[8.1]
  def up
    # Convert reply triggers: extract response_text from JSON, wrap in a script
    execute <<~SQL
      UPDATE triggers
      SET script_body = '"' || REPLACE(
        json_extract(action_config, '$.response_text'),
        '"', '\"'
      ) || '"'
      WHERE action_type = 0
        AND script_body IS NULL
        AND action_config IS NOT NULL
        AND json_extract(action_config, '$.response_text') IS NOT NULL
    SQL

    # Convert log_only triggers: empty script that returns nil
    execute <<~SQL
      UPDATE triggers
      SET script_body = 'nil'
      WHERE action_type = 2
        AND script_body IS NULL
    SQL

    # Any remaining triggers without script_body get a nil default
    execute <<~SQL
      UPDATE triggers
      SET script_body = 'nil'
      WHERE script_body IS NULL
    SQL

    remove_column :triggers, :action_type
    remove_column :triggers, :action_config
  end

  def down
    add_column :triggers, :action_type, :integer, default: 0, null: false
    add_column :triggers, :action_config, :text
  end
end
