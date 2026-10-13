# Each university's chance of winning the season (優勝確率) just before and just
# after a game, for the game summary to say how the game moved the title race.
#
# The season is ranked as the league ranks it: by 勝ち点 (a card won by taking
# two games first), then by 勝率 (wins over decisions, draws left out). Teams
# level on both meet in a playoff (優勝決定戦), counted here as an even split.
#
# The results up to the day of the game are taken as they are, and every card
# not yet decided is played out with each remaining game an even chance (draws
# left out: a drawn game is replayed and leaves 勝率 as it was). Every outcome
# is counted exactly rather than sampled. Games of other cards on the same day
# count on both sides, so the change is this game's alone.
#
# Only for the second half of a season (OPEN_CARDS or fewer cards undecided),
# when the counting is quick and the odds mean something, and only for seasons
# played as best-of-three cards: not the 2020 formats, nor a season whose cards
# don't look like that (several prewar ones).
class ChampionshipOdds
  OPEN_CARDS = 7

  # { before: { university_id => probability }, after: { ... } }, or nil when
  # not worked out for this game.
  def self.around(game)
    return nil unless game.counted_in_stats && game.decided?
    return nil if GameDataCheck::SPECIAL_FORMATS.key?([ game.season.year, game.season.term ])

    season_games = Game.held.where(season_id: game.season_id, counted_in_stats: true).order(:played_on, :game_number).to_a
    key = [ "championship_odds/v1", game.id, season_games.map(&:updated_at).max&.to_i, season_games.size ]
    Rails.cache.fetch(key) { new(game, season_games).around }
  end

  def initialize(game, season_games)
    @game = game
    @season_games = season_games
    @team_ids = season_games.flat_map { |g| [ g.team0_id, g.team1_id ] }.uniq.sort
  end

  def around
    return nil unless best_of_three_cards?

    known = @season_games.select { |g| g.decided? && g.played_on <= @game.played_on }
    before = odds(known.reject { |g| g.id == @game.id })
    after = odds(known)
    before && after ? { before: before, after: after } : nil
  end

  private

  # Every pair's decided games stop at two wins for one side, and a season
  # that is over (nothing still to play) has every card decided.
  def best_of_three_cards?
    decided = @season_games.select(&:decided?)
    pairs.all? do |pair|
      wins = [ 0, 0 ]
      decided.select { |g| pair_of(g) == pair }.each do |g|
        return false if wins.max >= 2
        side = winner_side(g, pair)
        wins[side] += 1 if side
      end
      wins.max >= 2 || season_pending?
    end
  end

  def season_pending?
    @season_pending ||= Game.where(season_id: @game.season_id, game_status: %w[試合前 試合中]).exists? ||
      @game.season.year >= Date.current.year
  end

  def pairs
    @pairs ||= @team_ids.combination(2).to_a
  end

  def pair_of(game)
    [ game.team0_id, game.team1_id ].sort
  end

  # 0 or 1 for the winner's place in pair, nil for a draw.
  def winner_side(game, pair)
    return nil if game.team0_score == game.team1_score

    winner = game.team0_score > game.team1_score ? game.team0_id : game.team1_id
    pair.index(winner)
  end

  # { university_id => probability } given these results, or nil with too
  # many cards still open.
  def odds(results)
    n = @team_ids.size
    index = @team_ids.each_with_index.to_h
    # The state: points, wins and losses of each team, in @team_ids order.
    base = Array.new(3 * n, 0)
    open = []

    pairs.each do |pair|
      wins = [ 0, 0 ]
      results.select { |g| pair_of(g) == pair }.each do |g|
        side = winner_side(g, pair) or next
        wins[side] += 1
      end
      a, b = pair.map { |id| index[id] }
      base[n + a] += wins[0]
      base[2 * n + a] += wins[1]
      base[n + b] += wins[1]
      base[2 * n + b] += wins[0]
      if wins.max >= 2
        base[wins[0] >= 2 ? a : b] += 1
      else
        open << [ a, b, wins ]
      end
    end
    return nil if open.size > OPEN_CARDS

    states = { base => 1r }
    open.each do |a, b, wins|
      outcomes = card_outcomes(*wins)
      states = states.each_with_object(Hash.new(0r)) do |(state, p), next_states|
        outcomes.each do |(more_a, more_b), q|
          s = state.dup
          s[n + a] += more_a
          s[2 * n + a] += more_b
          s[n + b] += more_b
          s[2 * n + b] += more_a
          s[wins[0] + more_a >= 2 ? a : b] += 1
          next_states[s] += p * q
        end
      end
    end

    chances = Array.new(n, 0r)
    states.each do |state, p|
      champions = champions_of(state, n)
      champions.each { |i| chances[i] += p / champions.size }
    end
    @team_ids.zip(chances.map(&:to_f)).to_h
  end

  # The ways a card at a-b (games won by each side) can end, with no draws:
  # { [more games won by a, more by b] => probability }.
  def card_outcomes(a, b)
    return { [ 0, 0 ] => 1r } if a >= 2 || b >= 2

    card_outcomes(a + 1, b).transform_keys { |x, y| [ x + 1, y ] }.transform_values { |p| p / 2 }
      .merge(card_outcomes(a, b + 1).transform_keys { |x, y| [ x, y + 1 ] }.transform_values { |p| p / 2 }) { |_, p, q| p + q }
  end

  # The teams on most points and, among them, the best 勝率 (exact fractions).
  def champions_of(state, n)
    top_points = state.first(n).max
    leaders = (0...n).select { |i| state[i] == top_points }
    percentage = ->(i) { decided = state[n + i] + state[2 * n + i]; decided.zero? ? 0r : Rational(state[n + i], decided) }
    best = leaders.map(&percentage).max
    leaders.select { |i| percentage.(i) == best }
  end
end
