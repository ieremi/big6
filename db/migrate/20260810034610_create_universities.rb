class CreateUniversities < ActiveRecord::Migration[8.1]
  def change
    create_table :universities do |t|
      t.string :name
      t.string :short_name
      t.string :slug

      t.timestamps
    end
    add_index :universities, :slug, unique: true 
  end
end
