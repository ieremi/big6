class AllowPlayersWithoutEnterYear < ActiveRecord::Migration[8.1]
  # Some staff (部長, 監督, ...) are listed by Scorebook without an entry year.
  def change
    change_column_null :players, :enter_year, true
  end
end
