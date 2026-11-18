# 早慶戦は順位が下の方が勝ちやすいか, for the article on it: in each season,
# which of 早大 and 慶大 stood lower in the standings going into the 早慶戦
# (Standings over the games played before its first game: 勝ち点, then 勝率),
# and which of them took the card (more wins in it). Seasons where the two were
# level, or the card ended even (1勝1敗, or a tie), are left out.
#
# To set it against: every other card of the same seasons, the same way (the
# standings before the card's first game, and who took it), leaving out 東大's
# cards, which the other side nearly always takes.
#
# From 1938 spring, the first season Scorebook has every game of; playoffs
# (counted_in_stats false) are left out. Cached until a game changes.
class SokeiUnderdog
  FROM_YEAR = 1938

  # A season: its 早慶戦, who stood lower before it (:waseda, :keio), who took it,
  # their places then, and how far apart they were.
  Row = Data.define(:season, :lower, :winner, :waseda_rank, :keio_rank) do
    def lower_won? = lower == winner

    def gap = (waseda_rank - keio_rank).abs
  end

  # Another card: whether the side lower before it took it, and how far apart the two were.
  Card = Data.define(:lower_won, :gap)

  # Of some rows: how many, and how many the lower side took.
  Tally = Data.define(:count, :lower_won) do
    def rate = count.zero? ? nil : lower_won.fdiv(count)

    def self.of(rows) = new(count: rows.size, lower_won: rows.count { |row| row.respond_to?(:lower_won?) ? row.lower_won? : row.lower_won })
  end

  def self.rows = computed.fetch(:rows)

  def self.cards = computed.fetch(:cards)

  # The chance of the lower side taking as few as it did (or as many, the other
  # way) if each 早慶戦 were an even toss: the two-sided binomial p-value.
  def self.p_value(tally)
    n, k = tally.count, [ tally.lower_won, tally.count - tally.lower_won ].min
    tail = (0..k).sum { |i| n.downto(n - i + 1).inject(1, :*) / (1..i).inject(1, :*) }
    [ 2 * Rational(tail, 2**n), 1 ].min.to_f
  end

  def self.computed
    Rails.cache.fetch([ "sokei_underdog/v1", Game.maximum(:updated_at)&.to_i, Game.count ], expires_in: 1.week) { new.compute }
  end

  def compute
    universities = University.order(:position).to_a
    waseda, keio, tokyo = %w[waseda keio tokyo].map { |slug| universities.find { |u| u.slug == slug } }
    rows, cards = [], []
    Season.where(year: FROM_YEAR..).select(:id, :year, :term).order(:year, :term).each do |season|
      games = season.games.order(:played_on, :game_number).to_a.select { |game| game.decided? && game.counted_in_stats != false }
      games.group_by { |game| [ game.team0_id, game.team1_id ].sort }.each do |pair, card|
        first = card.map(&:played_on).min
        before = games.select { |game| game.played_on < first }
        next if before.empty?

        standings = Standings.new(season, games: before, universities:)
        a, b = pair.map { |id| standings.rows.find { |row| row.university.id == id } }
        order = a.standing_key <=> b.standing_key
        wins = pair.map { |id| card.count { |game| winner_id(game) == id } }
        next if order.zero? || wins.uniq.size == 1

        lower = (order.negative? ? a : b).university
        winner = (wins.first > wins.last ? a : b).university
        if pair.sort == [ waseda.id, keio.id ].sort
          by_slug = [ a, b ].index_by { |row| row.university.slug }
          rows << Row.new(season:, lower: lower.slug.to_sym, winner: winner.slug.to_sym, waseda_rank: by_slug["waseda"].rank, keio_rank: by_slug["keio"].rank)
        elsif pair.exclude?(tokyo.id)
          cards << Card.new(lower_won: lower == winner, gap: (a.rank - b.rank).abs)
        end
      end
    end
    { rows:, cards: }
  end

  private

  def winner_id(game)
    return if game.team0_score == game.team1_score

    game.team0_score > game.team1_score ? game.team0_id : game.team1_id
  end
end
