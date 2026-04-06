class CreateMessageLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :message_logs do |t|
      t.references :bot, null: false, foreign_key: true
      t.string :group_id, null: false
      t.string :author, null: false
      t.text :content, null: false
      t.string :direction, null: false
      t.datetime :message_at, null: false
      t.timestamps
    end

    add_index :message_logs, %i[bot_id group_id]
    add_index :message_logs, %i[bot_id message_at]
  end
end
