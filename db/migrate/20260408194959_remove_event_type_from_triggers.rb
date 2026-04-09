class RemoveEventTypeFromTriggers < ActiveRecord::Migration[8.1]
  def up
    remove_column :triggers, :event_type
  end

  def down
    add_column :triggers, :event_type, :integer, default: 0, null: false
  end
end
