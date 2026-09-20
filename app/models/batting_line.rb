# One batter's line for one game, imported by GameStatsImport.
class BattingLine < ApplicationRecord
  SUMMED_COLUMNS = %i[pa ab runs hits doubles triples home_runs total_bases rbi strikeouts walks sacrifices stolen_bases gidp fielding_errors].freeze

  belongs_to :game
  belongs_to :player
  belongs_to :university

  # The sum of several lines (a season, a career), with the rate stats worked out
  # from the sums. Each is nil when its denominator is 0.
  Totals = Struct.new(:games, *SUMMED_COLUMNS, keyword_init: true) do
    # Batting average.
    def average
      hits.to_f / ab unless ab.zero?
    end

    # On-base percentage: (hits + walks and hit-by-pitch) / (at-bats + walks and
    # hit-by-pitch). The usual formula also counts sacrifice flies in the
    # denominator, but Scorebook only gives bunts and flies together (and rarely
    # separately), so flies are left out. Counting every sacrifice as a fly would
    # lower it by 0.005 on average across players; flies are only some of them,
    # so the difference is smaller than that.
    def on_base_percentage
      (hits + walks).to_f / (ab + walks) unless (ab + walks).zero?
    end

    # Slugging percentage: total bases per at-bat.
    def slugging_percentage
      total_bases.to_f / ab unless ab.zero?
    end

    # On-base plus slugging.
    def ops
      obp = on_base_percentage
      slg = slugging_percentage
      obp + slg if obp && slg
    end
  end

  def self.totals(lines)
    Totals.new(games: lines.size, **SUMMED_COLUMNS.index_with { |column| lines.sum(&column) })
  end
end
