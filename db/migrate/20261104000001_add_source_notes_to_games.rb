class AddSourceNotesToGames < ActiveRecord::Migration[8.1]
  def change
    # Where a printed source disagrees with itself about the game (a column of
    # its box score not adding up to its total row, a line score's total), as
    # the transcription lists it under discrepancies: shown on the game page
    # with the citation. An array of sentences; nil for none.
    add_column :games, :source_notes, :jsonb
  end
end
