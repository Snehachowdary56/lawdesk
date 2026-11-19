class AddClientRefToTimeEntries < ActiveRecord::Migration[7.2]
  def change
    # Set by the mobile app; lets the API recognise a retried upload and not save it twice.
    add_column :time_entries, :client_ref, :string, limit: 64
    add_index :time_entries, :client_ref, unique: true
  end
end
