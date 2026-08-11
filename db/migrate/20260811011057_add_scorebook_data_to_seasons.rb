class AddScorebookDataToSeasons < ActiveRecord::Migration[8.1]
  def change
    add_column :seasons, :scorebook_data, :jsonb
  end
end
