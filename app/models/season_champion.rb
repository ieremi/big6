# The university that won a season, and how many seasons in a row it has won,
# for the game summary to say 「これで明大の3シーズン連続の優勝が決まった。」.
#
# The champion is decided as SeasonSummary says it: the winner of the playoff
# (優勝決定戦) when there was one, else the top of the standings (勝ち点, then
# 勝率). Only for seasons ranked that way (Season#ranked?); for the others, and
# for a season with two sides level at the top and no playoff, there is none.
#
# Works from the games alone, without the seasons' large Scorebook columns, so
# a run back through earlier seasons stays cheap.
class SeasonChampion
  # The champion of season (a University), or nil. The season is taken as over:
  # for the current one, ask only once its title is decided.
  def self.of(season)
    return nil unless season.ranked?

    games = Game.where(season_id: season.id).includes(:team0, :team1).order(:played_on, :game_number).to_a
    playoff = games.reverse.find { |game| !game.counted_in_stats && game.decided? && game.team0_score != game.team1_score }
    return (playoff.team0_score > playoff.team1_score ? playoff.team0 : playoff.team1) if playoff

    rows = Standings.new(season, games: games.select(&:counted_in_stats)).rows
    top, second = rows
    return nil if top.nil? || top.games.zero?
    return nil if second && [ second.points, second.percentage ] == [ top.points, top.percentage ]

    top.university
  end

  # How many seasons in a row university has won, counting season (taken as
  # won) and those just before it.
  def self.streak(season, university)
    count = 1
    while (season = season.previous) && of(season) == university
      count += 1
    end
    count
  end
end
