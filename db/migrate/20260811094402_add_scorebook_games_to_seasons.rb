class AddScorebookGamesToSeasons < ActiveRecord::Migration[8.1]
  def change
    add_column :seasons, :scorebook_games, :jsonb
  end
end
