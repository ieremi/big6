# The seasons grouped by the order of their cards (カードの順番): which pairs
# of universities met in which week, from the first week to the last. The
# league repeats a handful of schedules, so many seasons decades apart share
# one, and the 早慶戦 is always the last week on its own.
#
# A card's week is the day its first game was scheduled, a game called off
# included (a cancelled game keeps its date), so a rained-out card stays in
# the week it was planned for. Cards starting within two days of each other
# are one week. Only seasons with all fifteen cards are classified: from 1950,
# the formats before then having varied, and not 2020 or 2021 (Season#ranked?).
# Seasons with only a club history's games are left out by the same rule.
class CardOrders
  # A schedule: its weeks, each the cards begun that week (pairs of
  # universities, in display order), and the seasons that followed it.
  Order = Struct.new(:weeks, :seasons, keyword_init: true) do
    def key
      weeks.map { |cards| cards.map { |pair| pair.map(&:slug).join("-") }.join("+") }.join("/")
    end
  end

  CARDS = 15

  def self.all
    Rails.cache.fetch([ "card_orders/v1", Game.maximum(:updated_at)&.to_i, Game.count ]) { new.orders }
  end

  def orders
    universities = University.all.index_by(&:id)
    seasons = Season.select(:id, :year, :term).newest_first.to_a.select(&:ranked?)
    games = Game.where(season_id: seasons.map(&:id), counted_in_stats: true).pluck(:season_id, :played_on, :team0_id, :team1_id).group_by(&:first)

    orders = {}
    seasons.each do |season|
      weeks = weeks_of(Array(games[season.id]), universities) or next
      order = (orders[weeks] ||= Order.new(weeks: weeks, seasons: []))
      order.seasons << season
    end
    orders.values.sort_by { |order| [ -order.seasons.size, -order.seasons.first.year ] }
  end

  private

  # [[[University, University], ...], ...] per week, or nil without all the cards.
  def weeks_of(games, universities)
    first_day = {}
    games.sort_by { |_, day| day }.each do |_, day, team0_id, team1_id|
      first_day[[ team0_id, team1_id ].sort] ||= day
    end
    return nil unless first_day.size == CARDS

    weeks = []
    first_day.sort_by { |_, day| day }.each do |pair, day|
      if weeks.any? && (day - weeks.last[:day]).to_i <= 2
        weeks.last[:cards] << pair
      else
        weeks << { day: day, cards: [ pair ] }
      end
    end
    weeks.map do |week|
      week[:cards].map { |pair| pair.map { |id| universities.fetch(id) }.sort_by(&:position) }.sort_by { |pair| pair.map(&:position) }
    end
  end
end
