class CreateTasks < ActiveRecord::Migration[7.2]
  def change
    create_table :tasks do |t|
      t.references :matter, null: false, foreign_key: true
      t.references :document, foreign_key: true
      t.string :title, null: false
      t.date :due_on, null: false
      t.string :source, null: false, default: "manual"   # manual, rules or llm
      t.text :evidence                                    # the sentence the deadline came from
      t.string :status, null: false, default: "open"
      t.timestamps
    end
    add_index :tasks, %i[document_id due_on title], unique: true, length: { title: 191 }
    add_index :tasks, %i[matter_id status due_on]
  end
end
