class AddCountedInStatsToGames < ActiveRecord::Migration[8.1]
  # Scorebook leaves a few games (the 優勝決定戦 playoffs) out of players'
  # season and career stats and flags them isCounted: false. Games count by
  # default; the flag is backfilled from the game data already stored on each season.
  def up
    add_column :games, :counted_in_stats, :boolean, null: false, default: true

    execute <<~SQL
      UPDATE games
      SET counted_in_stats = false
      FROM seasons,
        LATERAL jsonb_array_elements(
          CASE WHEN jsonb_typeof(seasons.scorebook_games) = 'array' THEN seasons.scorebook_games ELSE '[]'::jsonb END
        ) AS info
      WHERE games.season_id = seasons.id
        AND games.scorebook_game_id = (info->>'id')::bigint
        AND info->>'isCounted' = 'false'
    SQL
  end

  def down
    remove_column :games, :counted_in_stats
  end
end
