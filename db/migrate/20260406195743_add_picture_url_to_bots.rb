class AddPictureUrlToBots < ActiveRecord::Migration[8.1]
  def change
    add_column :bots, :picture_url, :string
  end
end
