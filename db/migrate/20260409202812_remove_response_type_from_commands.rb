class RemoveResponseTypeFromCommands < ActiveRecord::Migration[8.1]
  def up
    remove_column :commands, :response_type
  end

  def down
    add_column :commands, :response_type, :integer, default: 3, null: false
  end
end
