class AddDescriptionToBots < ActiveRecord::Migration[8.1]
  def change
    add_column :bots, :description, :text
  end
end
