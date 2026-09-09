class AddAttendanceToGames < ActiveRecord::Migration[8.1]
  def change
    add_column :games, :attendance, :integer
  end
end
