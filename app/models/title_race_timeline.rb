# The moments a season's title race (TitleRace) can be looked at, for the
# buttons on the standings page: how the race stood once each game had ended,
# in the order they were played (TitleRace.order_key), grouped by week
# (SeasonWeeks). Only the games after which the race has its grid (or its
# champion) to show: none while more than ChampionshipOdds::OPEN_CARDS cards
# are open, nor while more than TitleRace::MAX_CARDS of them still matter.
#
# Also each university's chance of the title once each game had ended, from the
# first game after which it can be counted (chances), for the chart of how the
# chances moved over the season.
#
# Which games those are, and the chances, are cached with the games' results,
# as working out the race after each of some thirty games takes a while on the
# server; each race itself is cached by TitleRace.
class TitleRaceTimeline
  # A game to pick: the race as it stood once it had ended, the week it was
  # played in, and its key for the URL (after=2024-10-12-meiji-hosei: the day
  # and the two sides, as no pair plays twice in a day).
  Point = Struct.new(:game, :week, keyword_init: true) do
    def key
      "#{game.played_on}-#{game.team0.slug}-#{game.team1.slug}"
    end

    # "10/12 明大-法大", on its button.
    def short_label
      "#{game.played_on.strftime("%-m/%-d")} #{game.team0.short_name}-#{game.team1.short_name}"
    end

    # "10月12日の明大 3-2 法大（2回戦）".
    def label
      "#{game.played_on.strftime("%-m月%-d日")}の#{game.team0.short_name} #{game.team0_score}-#{game.team1_score} #{game.team1.short_name}（#{game.round_name}）"
    end
  end

  attr_reader :games

  def initialize(season, games: nil)
    @season = season
    @games = games || TitleRace.games_of(season)
  end

  # The games to choose from, in the order played. None when the season has no race to show.
  def points
    @points ||= begin
      ids = timeline[:eligible].to_set
      all_points.select { |point| ids.include?(point.game.id) }
    end
  end

  # Each university's chance of the title (TitleRace#chances) once each game had
  # ended, from the first game after which it can be counted, for the chart:
  # [[Point, { University => chance }], ...], in the order played. A university
  # without a chance is left out of a game's hash.
  def chances
    @chances ||= begin
      by_game = timeline[:chances]
      universities = University.where(id: by_game.values.flat_map(&:keys).uniq).index_by(&:id)
      all_points.filter_map do |point|
        game_chances = by_game[point.game.id] or next
        [ point, game_chances.to_h { |id, chance| [ universities.fetch(id), chance ] } ]
      end
    end
  end

  # The points grouped by week: { week number => [Point, ...] }, in order.
  def points_by_week
    points.group_by(&:week)
  end

  # The point for the game asked for (the after param), or the latest one.
  def find(key)
    points.find { |point| point.key == key.to_s } || points.last
  end

  # The title race once the point's game had ended (as it stands now for nil),
  # worked out once for each.
  def race(point)
    race_after(point&.game)
  end

  private

  def race_after(game)
    @races ||= {}
    @races[game&.id] ||= TitleRace.new(@season, games: @games, after: game)
  end

  # A Point for every game ended, in the order played.
  def all_points
    @all_points ||= begin
      weeks = week_numbers
      decided_in_order.map { |game| Point.new(game: game, week: weeks[game.id]) }
    end
  end

  # What is cached: { eligible: the ids of the games to pick, chances: { game id => { university id => chance } } }.
  def timeline
    @timeline ||= Rails.cache.fetch(cache_key, expires_in: 1.week) { compute }
  end

  def decided_in_order
    @games.select(&:decided?).sort_by { |game| TitleRace.order_key(game) }
  end

  # The games after which the race has something to show (see the class comment),
  # and the chances after every game it can be counted after (a grid too big to
  # draw still has them).
  def compute
    eligible = []
    chances = {}
    decided_in_order.each do |game|
      next if open_cards_after(game) > ChampionshipOdds::OPEN_CARDS

      race = race_after(game)
      next unless race.applicable?

      chances[game.id] = race.chances.to_h { |university, chance| [ university.id, chance ] }
      eligible << game.id unless race.too_many_cards?
    end
    { eligible: eligible, chances: chances }
  end

  # Varies with every result and every game still to play, as TitleRace's key does.
  def cache_key
    games = @games.map { |game| [ game.id, game.team0_id, game.team1_id, game.team0_score, game.team1_score, game.played_on, game.game_order, game.game_number ].join(":") }.sort
    [ "title_race_timeline/v2", @season.id, Digest::MD5.hexdigest(games.join(",")) ].join("/")
  end

  # { game id => the number of the week it was played in }.
  def week_numbers
    SeasonWeeks.new(@games).weeks.each_with_object({}) do |week, numbers|
      week.games.each { |game| numbers[game.id] = week.number }
    end
  end

  # How many cards were still open once the game had ended: pairs neither of
  # which had won two of their games by then.
  def open_cards_after(last)
    key = TitleRace.order_key(last)
    @games.group_by { |game| [ game.team0_id, game.team1_id ].sort }.count do |_, games|
      wins = games.select { |game| game.decided? && (TitleRace.order_key(game) <=> key) <= 0 && game.team0_score != game.team1_score }
        .map { |game| game.team0_score > game.team1_score ? game.team0_id : game.team1_id }.tally
      wins.values.max.to_i < 2
    end
  end
end
