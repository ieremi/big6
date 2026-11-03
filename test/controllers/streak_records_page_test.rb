require "test_helper"

# 連続記録 and ひさしぶりの記録 (StreakRecords) on a season's records tab.
class StreakRecordsPageTest < ActionDispatch::IntegrationTest
  setup do
    Game.delete_all
    others = %w[gamma delta epsilon].each_with_index.map do |slug, i|
      University.create!(name: "#{slug.capitalize} University", short_name: slug.capitalize, slug: slug, position: 3 + i)
    end
    @order = [ universities(:one), universities(:two), *others, University.create!(name: "東京大学", short_name: "東大", slug: "tokyo", position: 6) ]
    (0...7).each do |i|
      season = Season.find_or_create_by!(year: 2001 + i / 2, term: i.even? ? "spring" : "autumn")
      @order.combination(2).each_with_index do |(winner, loser), j|
        2.times do |n|
          Game.create!(season: season, team0: winner, team1: loser, played_on: Date.new(season.year, i.even? ? 4 : 9, 1) + j * 2 + n,
            game_number: n + 1, team0_score: 3, team1_score: 1, game_status: "試合終了")
        end
      end
    end
  end

  test "the records tab lists the runs the season adds to, with how each stands" do
    get records_season_url(2004, "spring")

    assert_response :success
    assert_select "section.streak-records h2", "連続記録"
    assert_select "section.streak-records li", text: /Alpha\s+優勝　7季連続（2001年春〜）/
    assert_select "section.streak-records li .muted", text: /1950年以降で歴代1位。Alphaで最長。/
  end

  test "and what it brings back after a long while" do
    season = Season.find_by!(year: 2004, term: "spring")
    Game.where(season: season, team0: universities(:one), team1: @order[2]).update_all("team0_id = team1_id, team1_id = team0_id")

    get records_season_url(2004, "spring")

    assert_select "section.streak-records h2", "ひさしぶりの記録"
    assert_select "section.streak-records li", text: /Gamma\s+Alphaから勝ち点　1950年以降初/
  end
end
