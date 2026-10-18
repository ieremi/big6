# The title race (優勝のゆくえ) of a season still being played: who wins the
# season for every way the cards still open can end, as a grid, the way fans
# chart it — each open card's possible results (2-0, 2-1, 1-2, 0-2 from the
# side of the university named first) along one side or the other, and the
# champion in each cell. The standings page shows it under the table.
#
# The season is ranked as ChampionshipOdds ranks it (and the league does): by
# 勝ち点, then by 勝率 as an exact fraction, teams level on both meeting in a
# playoff (優勝決定戦), which a cell shows as all their names. A card's result
# fixes the wins and losses it adds, so every cell is exact. Draws are left out:
# a drawn game is replayed, and leaves 勝率 as it was.
#
# A card none of whose results ever changes the champion (whatever the others
# do) is left out of the grid, so it only has the cards that matter. Only for a
# season played as best-of-three cards (not the 2020 formats, nor one from
# printed sources), with at most ChampionshipOdds::OPEN_CARDS cards open (to
# count) and at most MAX_CARDS of them mattering (to draw: 4 cards make a grid
# of up to 16 by 16).
class TitleRace
  MAX_CARDS = 4

  # A card still open: its two universities (first: the one named first, team0
  # of its first game as the schedule lists it), the week it is played in, the
  # games each has won so far, and the ways it can end, each [games won by first
  # in the card, by second] — from 1-0, [2, 0], [2, 1] and [1, 2] — with the
  # chance of each (paths: { result => how many orders of wins and losses reach it }).
  Card = Struct.new(:first, :second, :week, :wins, :results, :paths, keyword_init: true) do
    def label
      "#{TitleRace.circled(week)}#{first.short_name[0]}-#{second.short_name[0]}"
    end
  end

  attr_reader :season

  def initialize(season, games: nil)
    @season = season
    @games = games || Game.held.where(season_id: season.id, counted_in_stats: true).includes(:team0, :team1).to_a
  end

  # Whether there is a race to show: the season is played in cards, some are still open, and few enough to count.
  def applicable?
    computed.present?
  end

  # The cards on the grid (the ones that matter), in the order they are played.
  def cards
    computed&.fetch(:cards) || []
  end

  # The cards along the left (the earlier half, the larger when odd, which keeps
  # the grid narrow) and along the top (the rest). A single card goes along the top.
  def row_cards
    cards.size == 1 ? [] : cards.first((cards.size + 1) / 2)
  end

  def column_cards
    cards.drop(row_cards.size)
  end

  # The champions of the cell for these results of the grid's cards (in card order).
  def champions_for(results)
    computed.fetch(:champions).fetch(results)
  end

  # Every combination of results of these cards, in grid order ([[]] for none).
  def self.combinations(cards)
    cards.inject([ [] ]) { |combos, card| combos.product(card.results).map { |combo, result| combo + [ result ] } }
  end

  # The universities on top whatever happens, once no card left can change them
  # (the grid then has no cards): one, the champion, or a playoff's; nil while the
  # race is open.
  def settled
    return nil unless applicable? && cards.empty?

    computed.fetch(:champions).values.first
  end

  # Too many cards matter to draw the grid yet (the race is applicable, but the grid would be too big).
  def too_many_cards?
    computed.present? && computed[:too_many]
  end

  # { University => its chance of winning the season }, highest first, with every
  # game still to play an even chance and a playoff an even split; only the
  # universities with a chance.
  def chances
    computed&.fetch(:chances) || {}
  end

  def self.circled(number)
    number.between?(1, 20) ? (0x2460 + number - 1).chr(Encoding::UTF_8) : "(#{number})"
  end

  private

  # The race, worked out once and cached (on plain ids: the universities are looked
  # up again on reading) until a game finishes: only decided games (and which are
  # still to play) are in the key, so a live game's score changing every few
  # minutes doesn't work it all out again. The worst case (7 cards open) takes
  # seconds on the server.
  def computed
    return @computed if defined?(@computed)

    data = Rails.cache.fetch(cache_key, expires_in: 1.week) { compute }
    @computed = data && hydrate(data)
  end

  def cache_key
    decided = @games.select(&:decided?).map { |game| [ game.id, game.team0_id, game.team1_id, game.team0_score, game.team1_score ].join(":") }.sort
    still_to_play = @games.reject(&:decided?).map { |game| [ game.id, game.team0_id, game.team1_id, game.played_on, game.game_number ].join(":") }.sort
    [ "title_race/v1", season.id, Digest::MD5.hexdigest((decided + [ "|" ] + still_to_play).join(",")) ].join("/")
  end

  # The cached data with its ids turned back into universities and cards.
  def hydrate(data)
    universities = University.where(id: data[:team_ids]).index_by(&:id)
    cards = data[:cards].map do |card|
      Card.new(first: universities.fetch(card[:first]), second: universities.fetch(card[:second]), week: card[:week], wins: card[:wins],
        results: card[:results], paths: card[:paths])
    end
    {
      cards: cards,
      champions: data[:champions].transform_values { |ids| ids.map { |id| universities.fetch(id) } },
      chances: data[:chances].to_h { |id, chance| [ universities.fetch(id), chance ] },
      too_many: data[:too_many]
    }
  end

  def compute
    return nil if GameDataCheck::SPECIAL_FORMATS.key?([ season.year, season.term ])
    return nil if @games.empty? || @games.any?(&:source_citation)

    teams = @games.flat_map { |game| [ game.team0, game.team1 ] }.uniq.sort_by(&:position)
    index = teams.each_with_index.to_h { |team, i| [ team.id, i ] }
    weeks = week_numbers

    # Each team's points, wins and losses so far, in teams order.
    points, wins, losses = Array.new(teams.size, 0), Array.new(teams.size, 0), Array.new(teams.size, 0)
    open = []
    @games.group_by { |game| [ game.team0_id, game.team1_id ].sort }.each do |pair, games|
      ordered = games.sort_by { |game| [ game.played_on, game.game_number.to_i ] }
      first, second = ordered.first.team0, ordered.first.team1
      won = { first.id => 0, second.id => 0 }
      ordered.select(&:decided?).each do |game|
        return nil if won.values.max >= 2 # more games after a card was won: not played in cards

        winner = winner_id(game) or next
        won[winner] += 1
      end
      a, b = index[first.id], index[second.id]
      wins[a] += won[first.id]
      losses[a] += won[second.id]
      wins[b] += won[second.id]
      losses[b] += won[first.id]
      if won.values.max >= 2
        points[won[first.id] >= 2 ? a : b] += 1
      else
        paths = card_paths(won[first.id], won[second.id]).tally
        open << { first: first.id, second: second.id, a: a, b: b, week: weeks[pair], position: first.position,
          wins: [ won[first.id], won[second.id] ], results: paths.keys.sort_by { |x, y| [ -x, y ] }, paths: paths }
      end
    end
    return nil if open.empty? || open.size > ChampionshipOdds::OPEN_CARDS

    open.sort_by! { |card| [ card[:week].to_i, card[:position] ] }
    # Every combination of results as one number: card i's result (its place in
    # its results) is a digit in base RADIX, so the counting needs no nested arrays.
    codes = (0...(RADIX**open.size)).select { |code| open.each_with_index.all? { |card, i| digit(code, i) < card[:results].size } }
    champions = codes.to_h { |code| [ code, champions_of(points, wins, losses, open, code) ] }
    chances = chances_of(open, codes, champions, teams)

    mattering = open.each_index.select { |i| matters?(i, champions) }
    grid = champions.each_with_object({}) do |(code, top), h|
      h[mattering.map { |i| open[i][:results][digit(code, i)] }] = top.map { |t| teams[t].id }
    end
    {
      team_ids: teams.map(&:id),
      cards: open.values_at(*mattering).map { |card| card.slice(:first, :second, :week, :wins, :results, :paths) },
      champions: grid, chances: chances, too_many: mattering.size > MAX_CARDS
    }
  end

  # The week each pair's card is played in (SeasonWeeks), by pair.
  def week_numbers
    SeasonWeeks.new(@games).weeks.each_with_object({}) do |week, numbers|
      week.series.each { |series| numbers[[ series.team0.id, series.team1.id ].sort] = week.number }
    end
  end

  def winner_id(game)
    return nil if game.team0_score == game.team1_score

    game.team0_score > game.team1_score ? game.team0_id : game.team1_id
  end

  # How a card at a-b can end, once for each order of wins and losses that gets
  # there (2-1 from 0-0 twice: won, lost, won and lost, won, won).
  def card_paths(a, b)
    return [ [ a, b ] ] if a >= 2 || b >= 2

    card_paths(a + 1, b) + card_paths(a, b + 1)
  end

  RADIX = 4 # a card has at most 4 results

  def digit(code, index)
    (code / (RADIX**index)) % RADIX
  end

  # The teams on top (their places in teams order) with this combination of the
  # open cards' results: on most points and, among them, the best 勝率 (compared
  # exactly, as fractions, by cross-multiplying).
  def champions_of(points, wins, losses, open, code)
    points, wins, losses = points.dup, wins.dup, losses.dup
    open.each_with_index do |card, index|
      x, y = card[:results][digit(code, index)]
      more_a, more_b = x - card[:wins][0], y - card[:wins][1]
      wins[card[:a]] += more_a
      losses[card[:a]] += more_b
      wins[card[:b]] += more_b
      losses[card[:b]] += more_a
      points[x >= 2 ? card[:a] : card[:b]] += 1
    end
    top = points.max
    leaders = points.each_index.select { |i| points[i] == top }
    # wins / (wins + losses), with no decisions counted as 0 / 1.
    better = ->(i, j) { (wins[i] * [ wins[j] + losses[j], 1 ].max) <=> (wins[j] * [ wins[i] + losses[i], 1 ].max) }
    best = leaders.max { |i, j| better.(i, j) }
    leaders.select { |i| better.(i, best).zero? }
  end

  # [[university id, its chance]], highest first: every game still to play an even
  # chance (a card ends at a result with ½ for each game it takes, for each order
  # of wins and losses that gets there), and a playoff an even split.
  def chances_of(open, codes, champions, teams)
    totals = Hash.new(0r)
    codes.each do |code|
      probability = open.each_with_index.inject(1r) do |p, (card, index)|
        x, y = card[:results][digit(code, index)]
        p * Rational(card[:paths].fetch([ x, y ]), 2**(x + y - card[:wins].sum))
      end
      top = champions.fetch(code)
      top.each { |t| totals[teams[t].id] += probability / top.size }
    end
    teams.filter_map { |team| [ team.id, totals[team.id].to_f, team.position ] if totals[team.id].positive? }
      .sort_by { |_, chance, position| [ -chance, position ] }.map { |id, chance, _| [ id, chance ] }
  end

  # Whether the card at index ever changes the champion: some results of the other
  # cards give different champions for different results of this one (compared
  # against its first result, the same combination otherwise).
  def matters?(index, champions)
    step = RADIX**index
    champions.any? do |code, top|
      d = digit(code, index)
      d.positive? && champions.fetch(code - d * step) != top
    end
  end
end
