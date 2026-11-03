# A season's 個人成績, for its tab of the season's pages: every player who
# batted or pitched that season with their totals, of every university or of
# those chosen, listed by university (in the league's order) and then by plate
# appearances or innings, as a team's own stats sheet is, rather than by a rate
# a handful of at-bats can top. Those who reach the league's minimum (規定打席,
# 規定投球回) are marked, as they are the ones the league ranks.
#
# The totals are PlayerRanking's with no minimum (the rankings page's, cached
# there), so the playoffs are left out the same way; the minimum is
# PlayerRanking::LEAGUE's, over every university whichever are shown.
class SeasonPlayerStats
  Row = Data.define(:player, :totals, :qualified)

  def initialize(season, university_ids: nil)
    @season = season
    @university_ids = university_ids
  end

  # The rows of the kind ("batting" or "pitching").
  def rows(kind)
    @rows ||= {}
    @rows[kind] ||= begin
      qualified = PlayerRanking.new(kind, season: @season, minimum: PlayerRanking::LEAGUE).entries.to_set { |entry| entry.player.id }
      volume = kind == "batting" ? :pa : :outs
      PlayerRanking.new(kind, season: @season, university_ids: @university_ids, minimum: 0).entries
        .sort_by { |entry| [ entry.player.university.position, -entry.totals.public_send(volume), entry.player.name ] }
        .map { |entry| Row.new(player: entry.player, totals: entry.totals, qualified: qualified.include?(entry.player.id)) }
    end
  end

  def any?
    PlayerRanking::KINDS.any? { |kind| rows(kind).any? }
  end

  # The date of the last game whose box score is in, as the league writes 「○月○日現在」.
  def through
    PlayerRanking::KINDS.filter_map { |kind| PlayerRanking.new(kind, season: @season).stats_through }.max
  end
end
