# One pitcher's line for one game, imported by GameStatsImport. Innings are
# kept as outs (3 to an inning) so partial innings add up exactly.
class PitchingLine < ApplicationRecord
  SUMMED_COLUMNS = %i[batters_faced outs hits home_runs walks strikeouts runs earned_runs pitches started complete_game shutout wins losses].freeze

  belongs_to :game
  belongs_to :player
  belongs_to :university

  # The sum of several lines (a season, a career), with the earned run average.
  Totals = Struct.new(:games, *SUMMED_COLUMNS, keyword_init: true) do
    # Earned runs per nine innings; nil when no out was recorded.
    def era
      earned_runs * 27.0 / outs unless outs.zero?
    end
  end

  # Innings pitched from outs, the way baseball writes them: 10 outs is "3 1/3".
  def self.innings_label(outs)
    whole, thirds = outs.divmod(3)
    thirds.zero? ? whole.to_s : "#{whole} #{thirds}/3"
  end

  def self.totals(lines)
    Totals.new(games: lines.size, **SUMMED_COLUMNS.index_with { |column| lines.sum(&column) })
  end
end
