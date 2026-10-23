require "test_helper"

class DraftEntrantsTest < ActiveSupport::TestCase
  setup do
    Game.delete_all
    @alpha = universities(:one)
    @beta = universities(:two)
    @star = Player.create!(scorebook_id: 20231001, university: @alpha, name: "一番 星", enter_year: 2023, position: "投手")
    @prospect = Player.create!(scorebook_id: 20231002, university: @alpha, name: "育成 枠", enter_year: 2023, position: "捕手")
    @second = Player.create!(scorebook_id: 20236001, university: @beta, name: "二番 手", enter_year: 2023, position: "内野手")
  end

  # A season won by winner, beating the other side 2-0 in its only card.
  def won(year, term, winner, loser)
    season = Season.find_or_create_by!(year: year, term: term)
    2.times do |i|
      Game.create!(season: season, team0: winner, team1: loser, played_on: Date.new(year, term == "spring" ? 5 : 10, 1 + i), game_number: i + 1,
        team0_score: 3, team1_score: 1, game_status: "試合終了")
    end
    season
  end

  def draft
    stub_method(DraftEntrants, :path, ->(_year) { file_fixture("draft_test.yml") }) { DraftEntrants.new(2026).tap(&:entrants) }
  end

  test "reads each player who filed, with the day his league received it and his pick" do
    entrants = draft.entrants

    assert_equal [ @star, @prospect, @second ], entrants.map(&:player) # by university, picked first by round, the 育成 draft after
    star = entrants.first
    assert_equal [ Date.new(2026, 10, 2), "阪神タイガース", "1位", "投手" ], [ star.filed_on, star.pick.team, star.pick.label, star.pick.position ]
    assert_equal "育成2位", entrants.second.pick.label
    assert_not entrants.last.picked?
    assert_equal [ [ @alpha, 2, 2 ], [ @beta, 1, 0 ] ], draft.by_university
    assert_equal [ @star, @prospect ], draft.picked.map(&:player)
  end

  test "counts the titles his university won in the four years from his entry year, only of seasons over" do
    won(2022, "autumn", @alpha, @beta) # before he entered
    alpha_spring = won(2023, "spring", @alpha, @beta)
    beta_autumn = won(2025, "autumn", @beta, @alpha)
    alpha_2026 = won(2026, "spring", @alpha, @beta)

    star, _, second = draft.entrants
    assert_equal [ alpha_spring, alpha_2026 ], star.titles
    assert_equal [ beta_autumn ], second.titles
  end

  test "a player in the file the site doesn't have is an error, not a row left out" do
    @second.destroy!

    assert_raises(KeyError) { draft }
  end
end
