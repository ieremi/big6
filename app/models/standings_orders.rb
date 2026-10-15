# The seasons grouped by their final standings (順位): the six universities
# from first to last. Some orders come back again and again (早明慶法立東 in
# six seasons from 2003 to 2024), though most seasons have one of their own.
#
# Ranked as the league ranks a season, by 勝ち点 and then 勝率 (Standings),
# with the winner of a playoff (優勝決定戦) first. Universities level on both
# are tied (同順位), and a tie makes a different order from one without it.
# Only seasons over and ranked that way are grouped (Season#ranked?): from
# 1950, not 2020 or 2021, with all fifteen cards played and none still to play.
class StandingsOrders
  # An order: its places, each the universities in it (more than one when
  # tied), and the seasons that ended that way.
  Order = Struct.new(:places, :seasons, keyword_init: true) do
    def key
      places.map { |universities| universities.map(&:slug).join("=") }.join("-")
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
    universities = University.order(:position).to_a
    seasons = Season.select(:id, :year, :term).newest_first.to_a.select(&:ranked?)
    games = Game.where(season_id: seasons.map(&:id))
      .select(:id, :season_id, :team0_id, :team1_id, :team0_score, :team1_score, :game_status, :counted_in_stats, :played_on, :attendance)
      .group_by(&:season_id)

    orders = {}
    seasons.each do |season|
      places = places_of(season, Array(games[season.id]), universities) or next
      (orders[places.map { |place| place.map(&:id) }] ||= Order.new(places: places, seasons: [])).seasons << season
    end
    orders.values.sort_by { |order| [ -order.seasons.size, -order.seasons.first.year ] }
  end

  private

  # [[University, ...], ...] from first place to last, or nil for a season
  # not over or without all its cards.
  def places_of(season, games, universities)
    return nil if games.empty? || games.any? { |game| game.scheduled? || game.in_progress? }

    league = games.select(&:counted_in_stats)
    return nil unless league.map { |game| [ game.team0_id, game.team1_id ].sort }.uniq.size == CARDS

    rows = Standings.new(season, games: league, universities: universities).rows
    places = rows.chunk_while { |a, b| [ a.points, a.percentage.round(6) ] == [ b.points, b.percentage.round(6) ] }
      .map { |tied| tied.map(&:university).sort_by(&:position) }

    if (winner = playoff_winner(games))
      top = places.first
      places = [ [ winner ], top - [ winner ], *places.drop(1) ].reject(&:empty?)
    end
    places
  end

  def playoff_winner(games)
    playoff = games.reverse.find { |game| !game.counted_in_stats && game.decided? && game.team0_score != game.team1_score }
    playoff && (playoff.team0_score > playoff.team1_score ? playoff.team0 : playoff.team1)
  end
end
