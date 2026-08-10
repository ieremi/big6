class CreateSeasons < ActiveRecord::Migration[8.1]
  def change
    create_table :seasons do |t|
      t.integer :year
      t.string :term

      t.timestamps
    end
  end
end
