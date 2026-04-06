class CreateTriggers < ActiveRecord::Migration[8.1]
  def change
    create_table :triggers do |t|
      t.references :bot, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :event_type, null: false, default: 0
      t.integer :condition_type, null: false, default: 0
      t.string :condition_value
      t.integer :action_type, null: false, default: 0
      t.text :action_config
      t.integer :position
      t.boolean :enabled, null: false, default: true
      t.timestamps
    end
  end
end
