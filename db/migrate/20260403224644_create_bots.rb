class CreateBots < ActiveRecord::Migration[8.1]
  def change
    create_table :bots do |t|
      t.string :name, null: false
      t.string :npub, null: false
      t.integer :status, null: false, default: 0
      t.text :error_message
      t.boolean :auto_accept_invitations, null: false, default: true
      t.timestamps
    end
    add_index :bots, :npub, unique: true
  end
end
