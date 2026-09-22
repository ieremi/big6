# Rankings of batters and of pitchers, over a career or a single season, shared
# by the rankings page and the Web API.
#
# A batting ranking is in order of OPS and a pitching ranking in order of earned
# run average (its default order), but either can be reordered by any of its
# columns (entries_sorted_by).
#
# Only players who reach a minimum are ranked, since a rate over a handful of plate
# appearances says nothing (one at-bat gives an OPS of 2.000). The minimum is of
# plate appearances for batting and of innings for pitching; whoever asks for the
# ranking can set it (0 is no minimum), and it is otherwise DEFAULT_MINIMUMS:
#
#   career: 40, season: 10 (plate appearances, or innings)
#
# Games left out of players' stats (the 優勝決定戦 playoffs) don't count, as on
# the player pages. Players with equal displayed values (three decimals for OPS,
# two for ERA) share a rank.
class PlayerRanking
  KINDS = %w[batting pitching].freeze

  # The minimum when none is asked for: plate appearances for batting, innings
  # pitched for pitching.
  DEFAULT_MINIMUMS = { "batting" => { season: 10, career: 40 }, "pitching" => { season: 10, career: 40 } }.freeze

  # The most a minimum can be asked to be (nobody has that many, but it keeps the SQL sane).
  MAX_MINIMUM = 100_000
  # rank is the position in the order shown; default_rank is the rank in the
  # ranking's default order (OPS for batting, ERA for pitching), which is the same
  # thing unless the entries were sorted by another column.
  Entry = Struct.new(:rank, :player, :totals, :default_rank)

  # The columns a ranking's table can be sorted by, in table order, each with how
  # to read its value from an Entry. The names are the ones the Web API uses.
  # Sorting reorders the rows and numbers them again in the new order.
  SORT_KEYS = {
    "batting" => {
      "rank" => ->(entry) { entry.rank },
      "player" => ->(entry) { entry.player.name },
      "university" => ->(entry) { entry.player.university.position },
      "ops" => ->(entry) { entry.totals.ops },
      "average" => ->(entry) { entry.totals.average },
      "obp" => ->(entry) { entry.totals.on_base_percentage },
      "slg" => ->(entry) { entry.totals.slugging_percentage },
      "games" => ->(entry) { entry.totals.games },
      "pa" => ->(entry) { entry.totals.pa },
      "ab" => ->(entry) { entry.totals.ab },
      "hits" => ->(entry) { entry.totals.hits },
      "home_runs" => ->(entry) { entry.totals.home_runs }
    },
    "pitching" => {
      "rank" => ->(entry) { entry.rank },
      "player" => ->(entry) { entry.player.name },
      "university" => ->(entry) { entry.player.university.position },
      "era" => ->(entry) { entry.totals.era },
      "games" => ->(entry) { entry.totals.games },
      "outs" => ->(entry) { entry.totals.outs },
      "wins" => ->(entry) { entry.totals.wins },
      "losses" => ->(entry) { entry.totals.losses },
      "hits" => ->(entry) { entry.totals.hits },
      "strikeouts" => ->(entry) { entry.totals.strikeouts },
      "walks" => ->(entry) { entry.totals.walks },
      "earned_runs" => ->(entry) { entry.totals.earned_runs }
    }
  }.freeze

  # Columns where the first click should give the smallest first: the rank, the
  # names (and universities, in the league's order), and ERA. The rest (counts and
  # batting rates) start with the largest.
  ASCENDING_FIRST = %w[rank player university era].freeze

  # Sorted by these, every row gets its own number. By the others, equal values
  # share one, compared as displayed (three decimals for the batting rates, two
  # for ERA, whole numbers for counts).
  NO_TIES = %w[player university].freeze
  TIE_DIGITS = { "ops" => 3, "average" => 3, "obp" => 3, "slg" => 3, "era" => 2 }.freeze

  attr_reader :kind, :season

  # kind is "batting" or "pitching". season nil ranks whole careers.
  # university_ids nil means any university. minimum nil is the default one.
  def initialize(kind, season: nil, university_ids: nil, minimum: nil)
    raise ArgumentError, "unknown ranking: #{kind.inspect}" unless KINDS.include?(kind)

    @kind = kind
    @season = season
    @university_ids = university_ids&.map(&:to_i)
    @minimum = minimum && Integer(minimum).clamp(0, MAX_MINIMUM)
  end

  # What the minimum is when none is asked for.
  def self.default_minimum(kind, season:)
    DEFAULT_MINIMUMS.fetch(kind).fetch(season ? :season : :career)
  end

  # A minimum from a request parameter: a whole number, or nil (so that the default
  # applies) for anything else, including a blank.
  def self.minimum_from(value)
    string = value.to_s.strip
    string.match?(/\A\d+\z/) ? [ string.to_i, MAX_MINIMUM ].min : nil
  end

  # The minimum in force: plate appearances for batting, innings for pitching.
  def minimum
    @minimum || self.class.default_minimum(kind, season: season)
  end

  # The ranked entries in the default order, best first. The expensive part
  # (summing every qualifying player's lines across, for a career ranking,
  # its whole history) is cached: the page has no pagination at the SQL
  # level, so every visit — and every sort-column click, a full reload —
  # redoes it from scratch otherwise, which was slow enough on the career
  # batting ranking (the default view) to time out under load.
  def entries
    @entries ||= Rails.cache.fetch(cache_key, expires_in: 6.hours) do
      rank_in_default_order(in_default_order(totals_by_player))
    end
  end

  # The same entries reordered by a column (a key of SORT_KEYS) in "asc" or "desc"
  # order; direction nil is the column's default. Ties stay in default order, and
  # blanks come last whichever way it is sorted. The rows are numbered again in
  # the new order (equal displayed values share a number, 1, 2, 2, 4), except when
  # sorting by "rank" itself, which keeps the ranks of the default order.
  def entries_sorted_by(key, direction = nil)
    reader = SORT_KEYS.fetch(kind).fetch(key)
    sign = (direction || self.class.default_direction(kind, key)) == "desc" ? -1 : 1

    sorted_entries = entries.each_with_index.sort do |(a, a_index), (b, b_index)|
      a_value = reader.call(a)
      b_value = reader.call(b)
      order = if a_value.nil? || b_value.nil?
        (a_value.nil? ? 1 : 0) - (b_value.nil? ? 1 : 0)
      else
        (a_value <=> b_value) * sign
      end
      order.zero? ? a_index <=> b_index : order
    end.map(&:first)

    key == "rank" ? sorted_entries : renumber(sorted_entries, key)
  end

  # The columns a kind of ranking can be sorted by.
  def self.sort_keys(kind)
    SORT_KEYS.fetch(kind).keys
  end

  # "asc" or "desc": which way a click on that column sorts first.
  def self.default_direction(kind, key)
    raise KeyError, "no #{key.inspect} column in the #{kind} ranking" unless SORT_KEYS.fetch(kind).key?(key)

    ASCENDING_FIRST.include?(key) ? "asc" : "desc"
  end

  # Seasons that have any stats of the kind, newest first, for choosing a period.
  def self.seasons_with_stats(kind)
    line_class = kind == "batting" ? BattingLine : PitchingLine
    # Newest first: within a year the autumn season is the later one (term: :desc would put spring first).
    Season.where(id: Game.where(id: line_class.select(:game_id), counted_in_stats: true).select(:season_id))
      .order(Arel.sql("seasons.year DESC, CASE seasons.term WHEN 'autumn' THEN 1 ELSE 0 END DESC"))
  end

  private

  def line_class
    kind == "batting" ? BattingLine : PitchingLine
  end

  def cache_key
    [
      "player_ranking/entries/v1", kind, season&.id || "career",
      @university_ids&.sort&.join(","), minimum, line_class.maximum(:updated_at)&.to_i
    ].join("/")
  end

  # { Player => Totals } for every player who reaches the minimum, summed in the
  # database so only one row per player comes back.
  def totals_by_player
    lines = line_class.joins(:game).where(games: { counted_in_stats: true })
    lines = lines.where(games: { season_id: season.id }) if season
    lines = lines.where(university_id: @university_ids) unless @university_ids.nil?

    sums = line_class::SUMMED_COLUMNS.map { |column| "SUM(#{line_class.table_name}.#{column}) AS #{column}" }
    rows = lines.group("#{line_class.table_name}.player_id").having(minimum_condition)
      .select("#{line_class.table_name}.player_id AS player_id", "COUNT(*) AS games", *sums).to_a

    players = Player.includes(:university).where(id: rows.map(&:player_id)).index_by(&:id)
    rows.to_h do |row|
      totals = line_class::Totals.new(games: row["games"], **line_class::SUMMED_COLUMNS.index_with { |column| row[column.to_s].to_i })
      [ players.fetch(row.player_id), totals ]
    end
  end

  # HAVING for the minimum: plate appearances, or innings (3 outs each).
  def minimum_condition
    kind == "batting" ? "SUM(batting_lines.pa) >= #{minimum}" : "SUM(pitching_lines.outs) >= #{minimum * 3}"
  end

  # [player, totals] pairs, best first by OPS (batting) or ERA (pitching); ties in
  # the value go to whoever has more plate appearances or innings, then by name.
  def in_default_order(totals_by_player)
    if kind == "batting"
      totals_by_player.select { |_, totals| totals.ops }.sort_by { |player, totals| [ -totals.ops, -totals.pa, player.name ] }
    else
      totals_by_player.select { |_, totals| totals.era }.sort_by { |player, totals| [ totals.era, -totals.outs, player.name ] }
    end
  end

  # Numbers the pairs in the default order. Equal displayed values share a rank;
  # the next rank skips ahead (1, 2, 2, 4).
  def rank_in_default_order(pairs)
    ranks = {}
    pairs.each_with_index.map do |(player, totals), index|
      value = default_order_value(totals)
      ranks[value] ||= index + 1
      Entry.new(ranks[value], player, totals, ranks[value])
    end
  end

  # Numbers entries by their position in the order they are now in.
  def renumber(sorted_entries, key)
    reader = SORT_KEYS.fetch(kind).fetch(key)
    ranks = {}

    sorted_entries.each_with_index.map do |entry, index|
      value = NO_TIES.include?(key) ? index : tie_value(key, reader.call(entry))
      ranks[value] ||= index + 1
      Entry.new(ranks[value], entry.player, entry.totals, entry.default_rank)
    end
  end

  def tie_value(key, value)
    digits = TIE_DIGITS[key]
    digits && value ? value.round(digits) : value
  end

  # The value the default order is by, as displayed: OPS or ERA.
  def default_order_value(totals)
    kind == "batting" ? totals.ops.round(3) : totals.era.round(2)
  end
end
