class AddDataCorrectionNoteToGames < ActiveRecord::Migration[8.1]
  def change
    add_column :games, :data_correction_note, :text
  end
end
