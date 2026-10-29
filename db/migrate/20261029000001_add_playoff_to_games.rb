class AddPlayoffToGames < ActiveRecord::Migration[8.1]
  def change
    # The name of a game outside the league's table that isn't the title
    # playoff, such as 1928 autumn's 3位決定戦 from the club's history (shown in
    # place of its round). Scorebook's own playoffs (優勝決定戦) have none.
    add_column :games, :playoff, :string
  end
end
