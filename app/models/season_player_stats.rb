# A season's 個人成績, for its tab of the season's pages: every player who
# batted or pitched that season with their totals, of every university or of
# those chosen. Those who reach the league's minimum (規定打席, 規定投球回) are
# ranked as the league ranks them, by batting average or by ERA, players with
# the same figure shown (three decimals, two) sharing a place; the rest follow
# unranked in the same order, as a rate over a handful of at-bats (one hit in
# one, 1.000) would otherwise top it. The tab shows the top places first
# (PlayerRanking::DEFAULT_TOP, ties included), and everyone on asking.
#
# The totals are PlayerRanking's with no minimum (the rankings page's, cached
# there), so the playoffs are left out the same way; the minimum is
# PlayerRanking::LEAGUE's, over every university whichever are shown.
class SeasonPlayerStats
  Row = Data.define(:rank, :player, :totals)

  # top: how many places to show (nil for every player), as PlayerRanking.top_from reads it.
  def initialize(season, university_ids: nil, top: nil)
    @season = season
    @university_ids = university_ids
    @top = top
  end

  # The rows of the kind ("batting" or "pitching") shown: the ranked ones in the
  # top places, or every one.
  def rows(kind)
    all = all_rows(kind)
    @top ? all.select { |row| row.rank && row.rank <= @top } : all
  end

  # How many players there are of the kind, shown or not.
  def count(kind)
    all_rows(kind).size
  end

  def any?
    PlayerRanking::KINDS.any? { |kind| all_rows(kind).any? }
  end

  # The date of the last game whose box score is in, as the league writes 「○月○日現在」.
  def through
    PlayerRanking::KINDS.filter_map { |kind| PlayerRanking.new(kind, season: @season).stats_through }.max
  end

  private

  # Every row of the kind: the ranked ones first, best first, then the rest in
  # the same order; a player with no rate (no at-bat, no out) last.
  def all_rows(kind)
    @all_rows ||= {}
    @all_rows[kind] ||= begin
      qualified = PlayerRanking.new(kind, season: @season, minimum: PlayerRanking::LEAGUE).entries.to_set { |entry| entry.player.id }
      # The figure shown, and which way is better.
      rate = kind == "batting" ? ->(totals) { totals.average&.round(3) } : ->(totals) { totals.era&.round(2) }
      better = kind == "batting" ? -1 : 1
      volume = kind == "batting" ? :pa : :outs
      entries = PlayerRanking.new(kind, season: @season, university_ids: @university_ids, minimum: 0).entries.sort_by do |entry|
        value = rate.(entry.totals)
        [ qualified.include?(entry.player.id) ? 0 : 1, value ? 0 : 1, value.to_f * better, -entry.totals.public_send(volume), entry.player.name ]
      end
      ranked = entries.select { |entry| qualified.include?(entry.player.id) && rate.(entry.totals) }
      entries.map do |entry|
        place = (ranked.index { |other| rate.(other.totals) == rate.(entry.totals) } + 1 if ranked.include?(entry))
        Row.new(rank: place, player: entry.player, totals: entry.totals)
      end
    end
  end
end
