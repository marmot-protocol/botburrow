class AddScriptSupport < ActiveRecord::Migration[8.1]
  def change
    add_column :bots, :script_data, :text, default: "{}", null: false
    add_column :triggers, :script_body, :text
    add_column :scheduled_actions, :script_body, :text
  end
end
