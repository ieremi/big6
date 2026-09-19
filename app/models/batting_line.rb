# One batter's line for one game, imported by GameStatsImport.
class BattingLine < ApplicationRecord
  SUMMED_COLUMNS = %i[pa ab runs hits doubles triples home_runs rbi strikeouts walks sacrifices stolen_bases gidp fielding_errors].freeze

  belongs_to :game
  belongs_to :player
  belongs_to :university

  # The sum of several lines (a season, a career), with the batting average.
  Totals = Struct.new(:games, *SUMMED_COLUMNS, keyword_init: true) do
    # nil when there was no at-bat.
    def average
      hits.to_f / ab unless ab.zero?
    end
  end

  def self.totals(lines)
    Totals.new(games: lines.size, **SUMMED_COLUMNS.index_with { |column| lines.sum(&column) })
  end
end
