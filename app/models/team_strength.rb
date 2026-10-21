# How strong each university looked as a season went on (強さの推移), for the
# chart on the standings page: before the opening day, and once each game had
# ended, its chance of beating an average side (one of the six's mean strength).
#
# A university's strength is a logistic regression's score on two win rates:
# its last PAST_SEASONS seasons' (the long-run level, 東大's weakness above
# all) and this season's so far, each eased towards .500 by a few games' worth
# (PAST_PRIOR, CURRENT_PRIOR) so a side that wins its first two doesn't shoot
# up. The chance that one side beats another is the logistic of the difference
# of their scores, so against a side of the mean strength it is the logistic
# of the side's score less the mean.
#
# The weights were fitted on the games up to 2009 and checked on those from
# 2010 (script/big6/fit_team_strength.rb, 2026-10-21): log loss 0.554 against
# 0.693 for an even chance in every game, 69% of games called right. Most of
# that is 東大: among the other five the model is only a little better than an
# even chance (0.681), so a few points between two of them is within error.
# Only wins and losses move it: runs, hits and pitchers don't come into it.
class TeamStrength
  PAST_SEASONS = 10
  PAST_WEIGHT = 3.18
  CURRENT_WEIGHT = 1.95
  PAST_PRIOR = 2
  CURRENT_PRIOR = 3

  # A win rate eased towards .500 by prior games' worth of one.
  def self.rate(record, prior)
    wins, losses = record
    (wins + prior) / (wins + losses + 2.0 * prior)
  end

  def initialize(season)
    @season = season
  end

  # Whether there is anything to chart: a season of the league's own games with a result.
  def applicable?
    games.any? && games.none?(&:source_citation)
  end

  # [[point, { University => chance of beating an average side }], ...]: first
  # the opening day (point nil), then each game ended (a TitleRaceTimeline::Point),
  # in the order played. A drawn game changes nothing, but is a point all the same.
  def points
    return [] unless applicable?

    @points ||= begin
      so_far = Hash.new { |hash, id| hash[id] = [ 0, 0 ] }
      weeks = week_numbers
      [ [ nil, chances(so_far) ] ] + games.select(&:decided?).sort_by { |game| TitleRace.order_key(game) }.map do |game|
        record(so_far, game)
        [ TitleRaceTimeline::Point.new(game: game, week: weeks[game.id]), chances(so_far) ]
      end
    end
  end

  # Each game ended, in the order played, with the two win rates of both its
  # sides as they were before it (for fitting the weights): [[game, features of
  # team0, features of team1], ...], features [past rate, this season's rate].
  def each_game_features
    so_far = Hash.new { |hash, id| hash[id] = [ 0, 0 ] }
    games.select(&:decided?).sort_by { |game| TitleRace.order_key(game) }.map do |game|
      row = [ game, features(game.team0_id, so_far), features(game.team1_id, so_far) ]
      record(so_far, game)
      row
    end
  end

  private

  # The season's held games counted in the standings (no playoff).
  def games
    @games ||= TitleRace.games_of(@season)
  end

  def universities
    @universities ||= games.flat_map { |game| [ game.team0, game.team1 ] }.uniq.sort_by(&:position)
  end

  def features(university_id, so_far)
    [ self.class.rate(past_records[university_id], PAST_PRIOR), self.class.rate(so_far[university_id], CURRENT_PRIOR) ]
  end

  def score(university_id, so_far)
    past, current = features(university_id, so_far)
    PAST_WEIGHT * past + CURRENT_WEIGHT * current
  end

  # Each university's chance of beating a side of the six's mean strength.
  def chances(so_far)
    scores = universities.to_h { |university| [ university, score(university.id, so_far) ] }
    mean = scores.values.sum / scores.size
    scores.transform_values { |value| 1 / (1 + Math.exp(-(value - mean))) }
  end

  # Adds the game's win and loss (a draw adds nothing).
  def record(so_far, game)
    return if game.team0_score == game.team1_score

    winner, loser = game.team0_score > game.team1_score ? [ game.team0_id, game.team1_id ] : [ game.team1_id, game.team0_id ]
    so_far[winner][0] += 1
    so_far[loser][1] += 1
  end

  # { university id => [wins, losses] } over the last PAST_SEASONS seasons'
  # games in the standings, draws and printed sources' games left out.
  def past_records
    @past_records ||= begin
      records = Hash.new { |hash, id| hash[id] = [ 0, 0 ] }
      Game.where(season_id: past_season_ids, counted_in_stats: true, source_citation: nil)
        .where.not(team0_score: nil).where.not(team1_score: nil).where("team0_score <> team1_score")
        .pluck(:team0_id, :team1_id, :team0_score, :team1_score).each do |team0, team1, score0, score1|
          winner, loser = score0 > score1 ? [ team0, team1 ] : [ team1, team0 ]
          records[winner][0] += 1
          records[loser][1] += 1
        end
      records
    end
  end

  def past_season_ids
    order = ->(year, term) { [ year, term == "spring" ? 0 : 1 ] }
    Season.pluck(:id, :year, :term)
      .select { |_, year, term| (order.(year, term) <=> order.(@season.year, @season.term)).negative? }
      .max_by(PAST_SEASONS) { |_, year, term| order.(year, term) }.map(&:first)
  end

  # { game id => the number of the week it was played in }.
  def week_numbers
    SeasonWeeks.new(games).weeks.each_with_object({}) do |week, numbers|
      week.games.each { |game| numbers[game.id] = week.number }
    end
  end
end
