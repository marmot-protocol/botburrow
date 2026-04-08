class RemoveWebhookSubsystem < ActiveRecord::Migration[8.1]
  def up
    # Convert any existing webhook commands to script type
    execute <<~SQL
      UPDATE commands
      SET response_type = 3,
          response_text = '# Former webhook URL: ' || response_text || CHAR(10) || 'nil'
      WHERE response_type = 2
    SQL

    drop_table :webhook_deliveries
    drop_table :webhook_endpoints
  end

  def down
    create_table :webhook_endpoints do |t|
      t.references :bot, null: false, foreign_key: true
      t.string :name, null: false
      t.string :url, null: false
      t.string :secret
      t.boolean :enabled, default: true, null: false
      t.timestamps
    end

    create_table :webhook_deliveries do |t|
      t.references :webhook_endpoint, null: false, foreign_key: true
      t.string :event_type, null: false
      t.text :request_body
      t.text :response_body
      t.integer :response_status
      t.boolean :success, default: false, null: false
      t.datetime :delivered_at
      t.timestamps
    end
  end
end
