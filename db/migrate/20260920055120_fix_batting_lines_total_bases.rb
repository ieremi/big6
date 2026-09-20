class FixBattingLinesTotalBases < ActiveRecord::Migration[8.1]
  # Scorebook's tb (total bases) is 0 on about a third of its batter rows, and
  # equals the hit breakdown on every row where it is filled in. Recompute it
  # from the hits, so slugging (and OPS) can be worked out from it.
  def up
    execute <<~SQL
      UPDATE batting_lines
      SET total_bases = hits + doubles + 2 * triples + 3 * home_runs
      WHERE total_bases <> hits + doubles + 2 * triples + 3 * home_runs
    SQL
  end

  # The old values were wrong (0), so there is nothing worth restoring.
  def down
  end
end
