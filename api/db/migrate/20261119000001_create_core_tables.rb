class CreateCoreTables < ActiveRecord::Migration[7.2]
  def change
    create_table :clients do |t|
      t.string :name, null: false
      t.string :email
      t.timestamps
    end
    add_index :clients, :name

    create_table :matters do |t|
      t.references :client, null: false, foreign_key: true
      t.string :title, null: false
      t.string :practice_area, null: false
      t.string :adverse_party
      t.string :status, null: false, default: "open"
      t.date :opened_on, null: false
      t.timestamps
    end
    add_index :matters, :status

    create_table :invoices do |t|
      t.references :matter, null: false, foreign_key: true
      t.string :number, null: false
      t.date :issued_on, null: false
      t.integer :total_cents, null: false
      t.timestamps
    end
    add_index :invoices, :number, unique: true

    create_table :time_entries do |t|
      t.references :matter, null: false, foreign_key: true
      t.references :invoice, foreign_key: true
      t.date :worked_on, null: false
      t.integer :minutes, null: false
      t.integer :rate_cents, null: false
      t.boolean :billable, null: false, default: true
      t.string :description, null: false
      t.timestamps
    end
    add_index :time_entries, %i[matter_id invoice_id billable]

    create_table :documents do |t|
      t.references :matter, null: false, foreign_key: true
      t.string :title, null: false
      t.text :body, null: false
      t.timestamps
    end
  end
end
