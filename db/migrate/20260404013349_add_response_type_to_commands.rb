class AddResponseTypeToCommands < ActiveRecord::Migration[8.1]
  def change
    add_column :commands, :response_type, :integer, default: 0, null: false
  end
end
