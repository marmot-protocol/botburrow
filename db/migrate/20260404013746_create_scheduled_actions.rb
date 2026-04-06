class CreateScheduledActions < ActiveRecord::Migration[8.1]
  def change
    create_table :scheduled_actions do |t|
      t.references :bot, null: false, foreign_key: true
      t.string :name, null: false
      t.string :schedule, null: false
      t.integer :action_type, null: false, default: 0
      t.text :action_config, null: false
      t.boolean :enabled, null: false, default: true
      t.datetime :last_run_at
      t.datetime :next_run_at
      t.timestamps
    end
  end
end
