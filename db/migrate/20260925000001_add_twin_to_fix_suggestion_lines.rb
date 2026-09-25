class AddTwinToFixSuggestionLines < ActiveRecord::Migration[8.1]
  def change
    # When the player's Scorebook member page also has a line of the same day
    # filed under a game of the player's own university (the "twin"), that
    # game's Scorebook id. The line filed under the wrong game is then not the
    # player's missing line of that game, but another box score that has
    # strayed in (FixSuggestion#stray?).
    add_column :fix_suggestion_lines, :twin_scorebook_game_id, :bigint
  end
end
