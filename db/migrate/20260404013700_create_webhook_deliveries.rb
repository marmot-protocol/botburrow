class CreateWebhookDeliveries < ActiveRecord::Migration[8.1]
  def change
    create_table :webhook_deliveries do |t|
      t.references :webhook_endpoint, null: false, foreign_key: true
      t.string :event_type, null: false
      t.text :request_body
      t.text :response_body
      t.integer :response_status
      t.boolean :success, null: false, default: false
      t.datetime :delivered_at

      t.timestamps
    end
  end
end
