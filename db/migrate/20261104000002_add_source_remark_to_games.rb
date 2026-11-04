class AddSourceRemarkToGames < ActiveRecord::Migration[8.1]
  def change
    # What a printed source says about how the game went that the line score
    # can't (「雨のため七回コールドゲーム」), shown on the game page under its
    # summary. Unlike source_notes, not a disagreement in the book.
    add_column :games, :source_remark, :text
  end
end
