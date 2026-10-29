# The seasons grouped by their final standings (順位): the six universities
# from first to last. Some orders come back again and again (早明慶法立東 in
# six seasons from 2003 to 2024), though most seasons have one of their own.
#
# Ranked as the league ranks a season, by 勝ち点 and then 勝率 (Standings),
# with the winner of a playoff (優勝決定戦) first. Universities level on both
# are tied (同順位), and a tie makes a different order from one without it.
#
# The 2020 and 2021 seasons (Season::POINTS_SEASONS), of one- and two-game
# cards, are ranked by points instead: a win 1, a draw 0.5, then 勝率, and two
# universities still level by the games between them (2020 spring's 法大
# over 慶大, its champion). This gives each of them its real champion.
#
# Only seasons over are grouped, from 1950 (Season::FIRST_YEAR_RANKED), with
# all fifteen cards played and none still to play.
class StandingsOrders
  # An order: its places, each the universities in it (more than one when
  # tied), and the seasons that ended that way.
  Order = Struct.new(:places, :seasons, keyword_init: true) do
    def key
      places.map { |universities| universities.map(&:slug).join("=") }.join("-")
    end

    # For sorting by the order: the universities' display positions from first
    # place to last (慶明早法立東 = 123456), so the orders sort by the 1st place,
    # then the 2nd and so on. Tied universities keep their display order.
    def sort_value
      places.flatten.map(&:position).join.to_i
    end

    # For sorting by the latest season: 20242 for 2024 autumn, 20241 for spring.
    def latest_season_value
      seasons.map { |season| season.year * 10 + (season.term == "autumn" ? 2 : 1) }.max
    end

    # 「早明慶法立東」, with 「=」 between universities tied: 「早明慶=法立東」.
    def label
      places.map { |universities| universities.map { |university| university.short_name[0] }.join("=") }.join
    end
  end

  CARDS = 15

  def self.all
    Rails.cache.fetch([ "standings_orders/v1", Game.maximum(:updated_at)&.to_i, Game.count ]) { new.orders }
  end

  def orders
    orders = {}
    places_by_season.each do |season, places|
      (orders[places.map { |place| place.map(&:id) }] ||= Order.new(places: places, seasons: [])).seasons << season
    end
    orders.values.sort_by { |order| [ -order.seasons.size, -order.seasons.first.year ] }
  end

  # { Season => places } for each season over, newest first (see Order); of
  # the seasons given, or all.
  def places_by_season(seasons = nil)
    universities = University.order(:position).to_a
    seasons = (seasons || Season.select(:id, :year, :term).newest_first).select { |season| season.ranked? || points_season?(season) }
    games = Game.where(season_id: seasons.map(&:id))
      .select(:id, :season_id, :team0_id, :team1_id, :team0_score, :team1_score, :game_status, :counted_in_stats, :playoff, :played_on, :attendance)
      .group_by(&:season_id)

    seasons.filter_map do |season|
      places = places_of(season, Array(games[season.id]), universities)
      [ season, places ] if places
    end.to_h
  end

  private

  # [[University, ...], ...] from first place to last, or nil for a season
  # not over or without all its cards.
  def places_of(season, games, universities)
    return nil if games.empty? || games.any? { |game| game.scheduled? || game.in_progress? }

    league = games.select(&:counted_in_stats)
    return nil unless league.map { |game| [ game.team0_id, game.team1_id ].sort }.uniq.size == CARDS

    rows = Standings.new(season, games: league, universities: universities).rows
    return points_places(rows, league) if points_season?(season)

    places = rows.chunk_while { |a, b| [ a.points, a.percentage.round(6) ] == [ b.points, b.percentage.round(6) ] }
      .map { |tied| tied.map(&:university).sort_by(&:position) }

    if (winner = playoff_winner(games))
      top = places.first
      places = [ [ winner ], top - [ winner ], *places.drop(1) ].reject(&:empty?)
    end
    places
  end

  def points_season?(season)
    Season::POINTS_SEASONS.include?([ season.year, season.term ])
  end

  # A win 1 point and a draw 0.5, then 勝率; two universities still level
  # are put in the order of the games between them, if one won more of them.
  def points_places(rows, games)
    key = ->(row) { [ row.wins * 2 + row.draws, row.percentage.round(6) ] }
    rows.sort_by { |row| [ key.(row).map(&:-@), row.university.position ] }
      .chunk_while { |a, b| key.(a) == key.(b) }
      .flat_map do |tied|
        universities = tied.map(&:university).sort_by(&:position)
        next [ universities ] unless universities.size == 2

        a, b = universities
        margin = head_to_head(a, b, games)
        margin.zero? ? [ universities ] : (margin.positive? ? [ [ a ], [ b ] ] : [ [ b ], [ a ] ])
      end
  end

  # a's wins less b's in the games between them.
  def head_to_head(a, b, games)
    games.sum do |game|
      next 0 unless [ game.team0_id, game.team1_id ].sort == [ a.id, b.id ].sort && game.decided? && game.team0_score != game.team1_score

      (game.team0_score > game.team1_score ? game.team0_id : game.team1_id) == a.id ? 1 : -1
    end
  end

  def playoff_winner(games)
    playoff = games.reverse.find { |game| game.title_playoff? && game.decided? && game.team0_score != game.team1_score }
    playoff && (playoff.team0_score > playoff.team1_score ? playoff.team0 : playoff.team1)
  end
end
