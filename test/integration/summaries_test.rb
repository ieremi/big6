require "test_helper"

# The plain-sentence summaries at the top of the game, player and season pages,
# which are their descriptions too.
class SummariesTest < ActionDispatch::IntegrationTest
  def summary_and_description
    [ css_select("p.game-summary").sole.text.strip, css_select("meta[name=description]").sole["content"] ]
  end

  test "a game page opens with the game in sentences, its description too" do
    get matchup_game_url("alpha", "beta", 2026, "spring", 1)

    summary, description = summary_and_description
    assert_match "東京六大学野球 2026年春季リーグ戦 第1回戦", summary
    assert_equal summary, description
  end

  test "a player page and a season page do the same" do
    player = Player.create!(scorebook_id: 20246018, university: universities(:one), name: "田中 優飛", enter_year: 2024, role: "選手", position: "投手")

    get player_url(player)
    summary, description = summary_and_description
    assert_match "田中 優飛は、東京六大学野球・#{universities(:one).name}の投手。", summary
    assert_equal summary, description

    get season_url(2026, "spring")
    summary, description = summary_and_description
    assert_match "東京六大学野球 2026年春季リーグ戦は、", summary
    assert_equal summary, description
  end
end
