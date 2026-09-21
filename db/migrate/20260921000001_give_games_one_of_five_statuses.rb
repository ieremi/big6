# A game is in one of five states (Game.game_status): 試合前, 試合中, 試合終了,
# 中止, ノーゲーム. Rows imported before the status was tracked, or made from the
# league's schedule page, have none: it comes from the score, and the date when
# there is no score, as the pages used to show it. A cancelled (中止) game has no
# round number, since its replay has it.
class GiveGamesOneOfFiveStatuses < ActiveRecord::Migration[8.1]
  STATUSES = %w[試合前 試合中 試合終了 中止 ノーゲーム].freeze

  def up
    change_column_null :games, :game_number, true

    execute <<~SQL.squish
      UPDATE games SET game_status = CASE
        WHEN team0_score IS NOT NULL AND team1_score IS NOT NULL THEN '試合終了'
        WHEN played_on >= CURRENT_DATE THEN '試合前'
        ELSE '試合中'
      END
      WHERE game_status IS NULL OR game_status NOT IN (#{STATUSES.map { |status| connection.quote(status) }.join(', ')})
    SQL

    execute "UPDATE games SET game_number = NULL WHERE game_status = '中止'"

    change_column_default :games, :game_status, from: nil, to: "試合前"
    change_column_null :games, :game_status, false
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "the round numbers of cancelled games are gone"
  end
end
