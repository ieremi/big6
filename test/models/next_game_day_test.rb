require "test_helper"

class NextGameDayTest < ActiveSupport::TestCase
  setup do
    Game.delete_all
    @alpha, @beta = universities(:one), universities(:two)
    @season = seasons(:two)
    @today = Date.new(2026, 11, 1)
  end

  def game(day, order, **attributes)
    Game.create!({ season: @season, team0: @alpha, team1: @beta, played_on: day, game_number: order, game_order: order, game_status: "試合前" }.merge(attributes))
  end

  test "the day is today when there are games today, in the order they are played" do
    second = game(@today, 2)
    first = game(@today, 1)
    game(@today + 1, 3)

    day = NextGameDay.new(today: @today)

    assert day.today?
    assert_equal [ first, second ], day.entries.map(&:game)
  end

  test "or the next day with games within the week, and none beyond it" do
    game(@today + 6, 1)

    assert_equal @today + 6, NextGameDay.new(today: @today).date
    assert_nil NextGameDay.new(today: @today - 1).date
  end

  test "each side's starting pitcher comes from the league site's provisional lineup before Scorebook has one" do
    player = Player.create!(scorebook_id: 1, university: @alpha, name: "湯田 統真", high_school: "仙台育英", enter_year: 2024, role: "選手", enrollment_status: 1)
    game(@today, 1, league_official_data: { "lineup" => [
      { "side" => "top", "order" => 1, "position" => "二", "name" => "岡田" },
      { "side" => "top", "order" => nil, "position" => "投", "name" => "湯田", "high_school" => "仙台育英" },
      { "side" => "bottom", "order" => nil, "position" => "投", "name" => "道本" }
    ] })

    pitchers = NextGameDay.new(today: @today).entries.first.starting_pitchers

    assert_equal player, pitchers[@alpha.id].player
    assert_equal [ nil, "道本" ], [ pitchers[@beta.id].player, pitchers[@beta.id].name ]
  end
end
