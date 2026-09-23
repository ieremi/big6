class AddApplyingFixSuggestions < ActiveRecord::Migration[8.1]
  def change
    # A batting line added by applying an approved FixSuggestion rather than
    # imported from Scorebook's game page. The import keeps these (it replaces
    # only its own), unless the game page comes to have the player's line
    # itself, which then takes its place.
    add_reference :batting_lines, :fix_suggestion, foreign_key: true

    # When an approved suggestion's lines were added to our batting lines, and
    # by whom.
    add_column :fix_suggestions, :applied_at, :datetime
    add_reference :fix_suggestions, :applied_by, foreign_key: { to_table: :users }
  end
end
