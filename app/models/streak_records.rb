# Runs of seasons in a row (連続記録) a season adds to, ends or has at stake,
# for the standings page: 「明大 2位以上 10季連続（2022年春〜）、1989年春の法大
# （18季）以来」, as fans count them when a place is settled. The kinds are KINDS:
# the title, a place (2位以上, Aクラス, 最下位), a winning record (勝ち越し), and
# a card won from the same opponent (勝ち点).
#
# Counted from 1950 (Season::FIRST_YEAR_RANKED), when the standings came to be
# ranked by 勝ち点, over the seasons with every card played. The 2020 and 2021
# seasons count for the places as Standings ranks them, but had no 勝ち点 to win:
# a run of cards won from one opponent stops there.
#
# For a season under way, a run is decided only once no result left can change
# it, as TitleRace counts the cards still open (place_range, margin_range,
# settled); before then, or with too many cards open to count, it is at stake.
# The seasons before it are worked out once and cached until a game changes.
class StreakRecords
  # A kind: its label, and whether a university's season counts towards it
  # (facts: the season's ranks, champion and wins less losses, by university id).
  Kind = Data.define(:key, :label)
  KINDS = [
    Kind.new(:champion, "優勝"), Kind.new(:top_two, "2位以上"), Kind.new(:a_class, "Aクラス（3位以上）"),
    Kind.new(:winning, "勝ち越し"), Kind.new(:last, "最下位"), Kind.new(:card, "勝ち点")
  ].freeze

  # A run shown: who, of what kind (from whom, for a card), how long, from when,
  # and its status: :decided (this season adds to it), :at_stake (it would) or
  # :ended (this season ended it, at count).
  Record = Data.define(:university, :kind, :opponent, :count, :from, :to, :status, :rank, :tied, :since, :own_best, :longest) do
    def label
      kind.key == :card ? "#{opponent.short_name}から#{kind.label}" : kind.label
    end
  end

  # A run of seasons in a row: its university (and opponent), its first and last
  # season (as [year, term]) and how many.
  Run = Data.define(:university_id, :opponent_id, :from, :to, :count)

  # The runs shown: at least this long, and not cards won from 東大, which the
  # others take all but every season.
  MIN_COUNT = 5

  def initialize(season)
    @season = season
  end

  # Whether the season is one the runs are counted over.
  def applicable?
    (@season.ranked? || @season.points_season?) && !@season.from_printed_sources?
  end

  # The records, most notable first: decided, at stake, then ended, each the longest first.
  def records
    return [] unless applicable?

    @records ||= compute
  end

  # { [year, term number] => facts } of every season over from 1950, oldest first;
  # facts are nil for a season not counted (not all its cards played). Cached.
  def self.history
    Rails.cache.fetch([ "streak_records/v1", Game.maximum(:updated_at)&.to_i, Game.count ], expires_in: 1.week) { build_history }
  end

  def self.build_history
    seasons = Season.select(:id, :year, :term).where(year: Season::FIRST_YEAR_RANKED..).to_a
      .select { |season| season.ranked? || season.points_season? }.sort_by { |season| key_of(season) }
    games = Game.where(season_id: seasons.map(&:id))
      .select(:id, :season_id, :team0_id, :team1_id, :team0_score, :team1_score, :game_status, :counted_in_stats, :playoff, :played_on, :attendance, :source_citation)
      .group_by(&:season_id)
    universities = University.order(:position).to_a

    seasons.to_h do |season|
      season_games = Array(games[season.id])
      over = over?(season_games)
      [ key_of(season), (facts_of(season, season_games, universities) if over) ]
    end
  end

  # Whether a season's games are over: none still to play today or later (Tokyo's
  # date). A game left 試合前 on a past day is one whose cancellation never
  # reached the data (2022 spring has two), not one still to come.
  def self.over?(games)
    today = ActiveSupport::TimeZone["Asia/Tokyo"].today
    games.any? && games.none? { |game| (game.scheduled? || game.in_progress?) && game.played_on >= today }
  end

  # [year, 1 for spring or 2 for autumn], to order the seasons by.
  def self.key_of(season)
    [ season.year, season.term == "spring" ? 1 : 2 ]
  end

  # A season's facts: each university's place (the winner of a playoff first,
  # the others level with it second), the champion, wins less losses, and each
  # card's winner by pair (none in a points season); nil without all 15 cards.
  def self.facts_of(season, games, universities)
    league = games.select(&:counted_in_stats)
    return nil if league.any?(&:source_citation)
    return nil unless league.map { |game| [ game.team0_id, game.team1_id ].sort }.uniq.size == StandingsOrders::CARDS

    rows = Standings.new(season, games: league, universities: universities).rows
    ranks = rows.to_h { |row| [ row.university.id, row.rank ] }
    top = rows.select { |row| row.rank == 1 }.map { |row| row.university.id }
    playoff = games.reverse.find { |game| game.title_playoff? && game.decided? && game.team0_score != game.team1_score }
    champion = playoff ? (playoff.team0_score > playoff.team1_score ? playoff.team0_id : playoff.team1_id) : (top.first if top.one?)
    (top - [ champion ]).each { |id| ranks[id] = 2 } if champion && top.size > 1

    cards = {}
    unless season.points_season?
      league.select(&:decided?).group_by { |game| [ game.team0_id, game.team1_id ].sort }.each do |pair, pair_games|
        cards[pair] = card_winner(pair_games)
      end
    end

    { ranks: ranks, champion: champion, margins: rows.to_h { |row| [ row.university.id, row.wins - row.losses ] }, cards: cards }
  end

  # The university id that won two of a card's decided games, or nil.
  def self.card_winner(games)
    games.select(&:decided?).reject { |game| game.team0_score == game.team1_score }
      .map { |game| game.team0_score > game.team1_score ? game.team0_id : game.team1_id }
      .tally.find { |_, count| count >= 2 }&.first
  end

  # Whether a season's facts count towards the kind for the university (and
  # opponent): a card only when won from that opponent.
  def self.counts?(kind, facts, university_id, opponent_id)
    case kind.key
    when :champion then facts[:champion] == university_id
    when :top_two then facts[:ranks][university_id] <= 2
    when :a_class then facts[:ranks][university_id] <= 3
    when :winning then facts[:margins][university_id].positive?
    when :last then facts[:ranks][university_id] == 6 # 6位: two level 5th have no 最下位 (2017 autumn)
    when :card then facts[:cards][[ university_id, opponent_id ].sort] == university_id
    end
  end

  private

  def compute
    history = self.class.history.select { |key, _| (key <=> season_key) == -1 }
    now = current_facts
    return [] if now[:over] && now[:facts].nil? # over, but not with every card played

    runs = KINDS.to_h { |kind| [ kind.key, runs_of(kind, history) ] }
    universities = University.all.index_by(&:id)
    KINDS.flat_map do |kind|
      pairs(kind, universities).filter_map do |university_id, opponent_id|
        record_for(kind, university_id, opponent_id, runs.fetch(kind.key), history, now, universities)
      end
    end.sort_by { |record| [ %i[decided at_stake ended].index(record.status), -record.count, KINDS.index(record.kind) ] }
  end

  def season_key
    self.class.key_of(@season)
  end

  # The pairs a kind is counted for: each university (no opponent), or for a card
  # each university and each opponent but 東大.
  def pairs(kind, universities)
    ids = universities.keys
    return ids.map { |id| [ id, nil ] } unless kind.key == :card

    tokyo = universities.values.find { |university| university.slug == "tokyo" }&.id
    ids.product(ids).reject { |a, b| a == b || b == tokyo }
  end

  # Every run of the kind over the history, for each university (and opponent).
  def runs_of(kind, history)
    keys = pairs(kind, University.all.index_by(&:id))
    keys.flat_map do |university_id, opponent_id|
      runs = []
      current = nil
      history.each do |key, facts|
        if facts && self.class.counts?(kind, facts, university_id, opponent_id)
          current = current ? current.with(to: key, count: current.count + 1) : Run.new(university_id:, opponent_id:, from: key, to: key, count: 1)
        else
          runs << current if current
          current = nil
        end
      end
      runs << current if current
      runs
    end
  end

  # The record of the university's run of the kind (from the opponent) going into
  # this season, if long enough to show.
  def record_for(kind, university_id, opponent_id, runs, history, now, universities)
    last_key = history.keys.last
    going = runs.find { |run| run.university_id == university_id && run.opponent_id == opponent_id && run.to == last_key }
    before = going&.count.to_i
    status = status_of(kind, university_id, opponent_id, now)

    if status == :ended
      return nil if before < MIN_COUNT

      return Record.new(university: universities[university_id], kind:, opponent: universities[opponent_id], count: before,
        from: going.from, to: going.to, status: :ended, rank: nil, tied: false, since: nil, own_best: false, longest: nil)
    end

    count = before + 1
    return nil if count < MIN_COUNT

    others = runs - [ going ]
    longer = others.count { |run| run.count > count }
    since = others.select { |run| run.count >= count }.max_by(&:to)
    own = others.select { |run| run.university_id == university_id && run.opponent_id == opponent_id }.map(&:count).max.to_i
    longest = others.max_by { |run| [ run.count, run.to ] }
    Record.new(university: universities[university_id], kind:, opponent: universities[opponent_id], count:,
      from: going&.from || season_key, to: season_key, status:, rank: longer + 1, tied: others.any? { |run| run.count == count },
      since: since && [ since, universities[since.university_id] ], own_best: count > own,
      longest: longest && longest.count > count ? [ longest, universities[longest.university_id] ] : nil)
  end

  # :decided, :at_stake or :ended for this season: from its facts once it is over,
  # or from what the cards still open can do.
  def status_of(kind, university_id, opponent_id, now)
    if now[:facts]
      counted = self.class.counts?(kind, now[:facts], university_id, opponent_id)
      return counted ? :decided : :ended
    end

    race = now[:race]
    university = University.new(id: university_id)
    if kind.key == :card
      winner = now[:cards][[ university_id, opponent_id ].sort]
      return :at_stake if winner.nil?

      return winner == university_id ? :decided : :ended
    end
    return :at_stake unless race&.applicable?

    best, worst = race.place_range(university)
    low, high = race.margin_range(university)
    case kind.key
    when :champion
      return :decided if race.settled&.map(&:id) == [ university_id ]

      race.chances.keys.map(&:id).include?(university_id) ? :at_stake : :ended
    when :top_two then decide(worst <= 2, best > 2)
    when :a_class then decide(worst <= 3, best > 3)
    when :winning then decide(low.positive?, high <= 0)
    when :last then decide(best == 6, worst < 6)
    end
  end

  def decide(decided, ended)
    return :decided if decided

    ended ? :ended : :at_stake
  end

  # This season's facts once it is over; while it is on, its race (TitleRace)
  # and the cards already won.
  def current_facts
    universities = University.order(:position).to_a
    games = Game.where(season_id: @season.id).includes(:team0, :team1).to_a
    over = self.class.over?(games)
    return { over: true, facts: self.class.facts_of(@season, games, universities) } if over

    cards = {}
    unless @season.points_season?
      games.select(&:counted_in_stats).group_by { |game| [ game.team0_id, game.team1_id ].sort }
        .each { |pair, pair_games| cards[pair] = self.class.card_winner(pair_games) }
    end
    { race: TitleRace.new(@season), cards: cards }
  end
end
