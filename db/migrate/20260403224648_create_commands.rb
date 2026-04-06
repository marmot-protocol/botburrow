class CreateCommands < ActiveRecord::Migration[8.1]
  def change
    create_table :commands do |t|
      t.references :bot, null: false, foreign_key: true
      t.string :name, null: false
      t.string :pattern, null: false
      t.text :response_text, null: false
      t.boolean :enabled, null: false, default: true
      t.timestamps
    end
    add_index :commands, [ :bot_id, :pattern ], unique: true
  end
end
