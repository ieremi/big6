require "test_helper"

class GameDataCheckTest < ActiveSupport::TestCase
  setup do
    Game.delete_all # the fixtures' two games, alpha v beta of 2026-08-10, would be a same-day finding of their own
    @alpha = universities(:one)
    @beta = universities(:two)
    @gamma = University.create!(name: "Gamma University", short_name: "Gamma", slug: "gamma", position: 3)
    @season = Season.create!(year: 1984, term: "autumn")
  end

  def game(team0, team1, day, number, team0_score: 3, team1_score: 1, season: @season, **attributes)
    Game.create!({ season: season, team0: team0, team1: team1, played_on: day, game_number: number,
      team0_score: team0_score, team1_score: team1_score, game_status: "試合終了" }.merge(attributes))
  end

  # A normal season of three universities: each pair a two-game series, won 2-0.
  def normal_season
    game(@alpha, @beta, "1984-09-15", 1)
    game(@alpha, @beta, "1984-09-16", 2)
    game(@alpha, @gamma, "1984-09-22", 1)
    game(@alpha, @gamma, "1984-09-23", 2)
    game(@beta, @gamma, "1984-09-29", 1)
    game(@beta, @gamma, "1984-09-30", 2)
  end

  def findings
    GameDataCheck.new.findings.group_by(&:kind)
  end

  test "a normal season has no findings" do
    normal_season

    assert_empty GameDataCheck.new.findings
  end

  test "two games of a university on one day, both sides the same university, and a run against different opponents" do
    normal_season
    game(@beta, @gamma, "1984-09-30", 3) # the same day as the 2nd game
    game(@gamma, @gamma, "1984-10-06", 1)

    found = findings
    assert_equal [ "same_day #{@beta.id} 1984-09-30", "same_day #{@gamma.id} 1984-09-30" ], found["same_day"].map(&:key).sort
    assert_equal 1, found["same_team"].size
    assert_equal "Gammaが1984-09-30に2試合", found["same_day"].find { |f| f.key.include?(@gamma.id.to_s) }.message
  end

  test "a university playing a different opponent the next day is a finding" do
    game(@alpha, @beta, "1984-09-15", 1)
    game(@alpha, @gamma, "1984-09-16", 1)

    finding = findings["opponent_change"].sole
    assert_equal "Alpha：1984-09-15 はBeta、1984-09-16 はGamma", finding.message
  end

  test "a series' round numbers repeated or missing, a game after 2 wins, and a series over with no one at 2 wins" do
    game(@alpha, @beta, "1984-09-15", 1)
    game(@alpha, @beta, "1984-09-16", 1) # repeated
    game(@alpha, @gamma, "1984-09-22", 1)
    game(@alpha, @gamma, "1984-09-24", 3) # no 2nd
    game(@alpha, @gamma, "1984-09-25", 4) # after alpha's 2 wins
    game(@beta, @gamma, "1984-09-29", 1)
    game(@beta, @gamma, "1984-09-30", 2, team0_score: 1, team1_score: 3) # 1-1, and the season is over
    game(@alpha, @beta, "1985-04-10", 1, season: Season.create!(year: 1985, term: "spring")) # a later season

    found = findings
    assert_equal [ "Alpha-Beta：回戦 1, 1" ], found["round_duplicate"].map(&:message)
    assert_equal [ "Alpha-Gamma：回戦 1, 3, 4" ], found["round_gap"].map(&:message)
    assert_equal [ "Alpha-Gamma：Alpha2勝のあとに 1984-09-25 Alpha vs Gamma 4回戦" ], found["after_decided"].map(&:message)
    assert_equal [ "Beta-Gamma：Beta1勝・Gamma1勝（2試合）" ], found["undecided"].map(&:message)
  end

  test "a playoff isn't counted towards a series, a season still being played isn't over, and 2020 is left out of the series checks" do
    normal_season
    game(@alpha, @beta, "1984-10-10", 1, counted_in_stats: false) # a playoff after alpha's 2 wins
    latest = Season.create!(year: 2021, term: "spring")
    game(@alpha, @beta, "2021-04-10", 1, season: latest) # one game in, the season going on
    covid = Season.create!(year: 2020, term: "spring")
    game(@alpha, @beta, "2020-08-10", 1, season: covid) # one game a pair
    game(@alpha, @gamma, "2020-08-12", 1, season: covid)
    game(@beta, @gamma, "2020-08-14", 1, season: covid)

    found = findings
    assert_nil found["after_decided"]
    assert_nil found["undecided"]
    assert_equal [ "round_duplicate" ], found.keys # the playoff's round 1 beside the series' own
  end

  test "a season missing a pair is a finding, and every finding keeps its key from one check to the next" do
    game(@alpha, @beta, "1984-09-15", 1)
    game(@alpha, @beta, "1984-09-16", 2)
    game(@beta, @gamma, "1984-09-29", 1)
    game(@beta, @gamma, "1984-09-30", 2)

    assert_equal [ "3校でカード 2（本来 3）" ], findings["pair_count"].map(&:message)
    assert_equal GameDataCheck.new.findings.map(&:key), GameDataCheck.new.findings.map(&:key)
  end
end
