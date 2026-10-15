require "test_helper"

class CardOrdersTest < ActiveSupport::TestCase
  # Six universities, fifteen cards over eight weeks: two a week, the last on its own.
  WEEKS = [ [ %w[a b], %w[c d] ], [ %w[e f], %w[a c] ], [ %w[b d], %w[e a] ], [ %w[f c], %w[b e] ],
            [ %w[d f], %w[a f] ], [ %w[b c], %w[d e] ], [ %w[c e], %w[b f] ], [ %w[a d] ] ].freeze

  setup do
    Game.delete_all
    University.delete_all
    @universities = %w[a b c d e f].each_with_index.to_h do |slug, index|
      [ slug, University.create!(name: slug, short_name: slug, slug: slug, position: index + 1) ]
    end
  end

  def play_season(year, term, weeks: WEEKS, cancel: nil)
    season = Season.create!(year: year, term: term)
    start = Date.new(year, term == "spring" ? 4 : 9, 10)
    weeks.each_with_index do |cards, week|
      cards.each do |team0, team1|
        day = start + week * 7
        status = cancel == [ team0, team1 ] ? "中止" : "試合終了"
        Game.create!(season: season, team0: @universities[team0], team1: @universities[team1], played_on: day,
          game_number: (1 unless status == "中止"), game_status: status)
        Game.create!(season: season, team0: @universities[team1], team1: @universities[team0], played_on: day + 1 + (status == "中止" ? 7 : 0),
          game_number: 1, game_status: "試合終了") if status == "中止"
      end
    end
    season
  end

  test "groups the seasons that played their cards in the same weeks" do
    first = play_season(1990, "spring")
    second = play_season(2010, "autumn")
    other = play_season(2000, "spring", weeks: [ WEEKS[1], WEEKS[0], *WEEKS[2..] ])

    orders = CardOrders.new.orders

    assert_equal [ [ second, first ], [ other ] ], orders.map(&:seasons)
    assert_equal 8, orders.first.weeks.size
    assert_equal [ [ @universities["a"], @universities["d"] ] ], orders.first.weeks.last
  end

  test "keeps a card called off in the week it was scheduled for" do
    first = play_season(1990, "spring")
    rained_out = play_season(1991, "spring", cancel: %w[c d])

    assert_equal [ [ rained_out, first ] ], CardOrders.new.orders.map(&:seasons)
  end

  test "leaves out seasons without all fifteen cards, and those not ranked by 勝ち点" do
    play_season(1990, "spring", weeks: WEEKS[0..6])
    play_season(2020, "autumn")
    play_season(1949, "spring")

    assert_empty CardOrders.new.orders
  end
end
