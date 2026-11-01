require "test_helper"

class StreakRecordsTest < ActiveSupport::TestCase
  setup do
    Game.delete_all
    @alpha, @beta = universities(:one), universities(:two)
    @gamma, @delta, @epsilon = %w[gamma delta epsilon].each_with_index.map do |slug, i|
      University.create!(name: "#{slug.capitalize} University", short_name: slug.capitalize, slug: slug, position: 3 + i)
    end
    @tokyo = University.create!(name: "東京大学", short_name: "東大", slug: "tokyo", position: 6)
  end

  # A season over, with every card played: each university takes its card from
  # every one after it in order, 2-0 (so they end in that order).
  def season(year, term, order)
    season = Season.find_or_create_by!(year: year, term: term)
    day = Date.new(year, term == "spring" ? 4 : 9, 1)
    order.combination(2).each_with_index do |(winner, loser), i|
      2.times do |n|
        Game.create!(season: season, team0: winner, team1: loser, played_on: day + i * 2 + n, game_number: n + 1,
          team0_score: 3, team1_score: 1, game_status: "試合終了")
      end
    end
    season
  end

  def order
    [ @alpha, @beta, @gamma, @delta, @epsilon, @tokyo ]
  end

  # Seasons from 2001 spring, count of them, each in the given order.
  def seasons(count, order)
    (0...count).map { |i| season(2001 + i / 2, i.even? ? "spring" : "autumn", order) }
  end

  def find(season, university, label)
    StreakRecords.new(season).records.find { |record| record.university == university && record.label == label }
  end

  test "a season over adds to the runs it continues, ranked against every other run of the kind" do
    seasons(6, order) # alpha champion 2001 spring to 2003 autumn
    target = season(2004, "spring", order)

    record = find(target, @alpha, "優勝")

    assert_equal :decided, record.status
    assert_equal 7, record.count
    assert_equal [ 2001, 1 ], record.from
    assert_equal 1, record.rank
    assert record.own_best
  end

  test "a season that ends a run says so, with how long it was" do
    seasons(6, order)
    target = season(2004, "spring", [ @gamma, @beta, @alpha, @delta, @epsilon, @tokyo ])

    record = find(target, @alpha, "2位以上")

    assert_equal :ended, record.status
    assert_equal [ 6, [ 2001, 1 ], [ 2003, 2 ] ], [ record.count, record.from, record.to ]
  end

  test "a run says since when one as long was last seen, and the longest when longer" do
    seasons(8, [ @beta, @alpha, @gamma, @delta, @epsilon, @tokyo ]) # beta champion 8 seasons, to 2004 autumn
    (0...5).each { |i| season(2005 + i / 2, i.even? ? "spring" : "autumn", order) } # then alpha, 5 seasons to 2007 spring
    target = season(2007, "autumn", order)

    record = find(target, @alpha, "優勝")

    assert_equal 6, record.count
    assert_equal 2, record.rank
    since, holder = record.since
    assert_equal [ @beta, 8, [ 2004, 2 ] ], [ holder, since.count, since.to ]
    longest, = record.longest
    assert_equal 8, longest.count
  end

  test "cards won from 東大 aren't shown, as everyone takes them" do
    seasons(6, order)
    target = season(2004, "spring", order)

    labels = StreakRecords.new(target).records.select { |record| record.university == @alpha }.map(&:label)

    assert_includes labels, "Betaから勝ち点"
    assert_not_includes labels, "東大から勝ち点"
  end

  test "a 2020 season counts for the places, but ends a run of cards, having no 勝ち点" do
    (0...6).each { |i| season(2017 + i / 2, i.even? ? "spring" : "autumn", order) } # to 2019 autumn
    target = season(2020, "spring", order)

    assert_equal [ :decided, 7 ], find(target, @alpha, "優勝").then { |record| [ record.status, record.count ] }
    assert_equal [ :ended, 6 ], find(target, @alpha, "Betaから勝ち点").then { |record| [ record.status, record.count ] }
  end

  test "while a season is on, a run is decided once no card left can change it, and at stake till then" do
    seasons(6, order)
    target = Season.create!(year: 2004, term: "spring")
    order.combination(2).each_with_index do |(winner, loser), i|
      open = [ winner, loser ] == [ @alpha, @beta ] # alpha v beta still to play
      2.times do |n|
        Game.create!(season: target, team0: winner, team1: loser, played_on: open ? Date.current + 7 + n : Date.new(2004, 4, 1) + i * 2 + n,
          game_number: n + 1, team0_score: (3 unless open), team1_score: (1 unless open), game_status: open ? "試合前" : "試合終了")
      end
    end

    assert_equal :decided, find(target, @alpha, "2位以上").status # second at worst, losing a playoff
    assert_equal :at_stake, find(target, @alpha, "優勝").status # beta level on points with a 2-0 card
    assert_equal :decided, find(target, @beta, "2位以上").status
    assert_equal :at_stake, find(target, @alpha, "Betaから勝ち点").status
  end

  # The 2004 spring season with every card over but alpha v beta, whose games
  # are given as [alpha's score, beta's] (nil for still to play).
  def season_with_alpha_beta(*scores)
    seasons(6, order)
    target = Season.create!(year: 2004, term: "spring")
    order.combination(2).each_with_index do |(winner, loser), i|
      next if [ winner, loser ] == [ @alpha, @beta ]

      2.times do |n|
        Game.create!(season: target, team0: winner, team1: loser, played_on: Date.new(2004, 4, 1) + i * 2 + n, game_number: n + 1,
          team0_score: 3, team1_score: 1, game_status: "試合終了")
      end
    end
    scores.each_with_index.map do |score, n|
      Game.create!(season: target, team0: @alpha, team1: @beta, played_on: Date.new(2004, 5, 20) + n, game_number: n + 1, game_order: 1,
        team0_score: score&.first, team1_score: score&.last, game_status: score ? "試合終了" : "試合前")
    end
  end

  def summary(game)
    GameSummary.new(game, scoreboard: GameScoreboard.new(game)).to_s
  end

  test "a game's summary says the runs it decided" do
    _first, second = season_with_alpha_beta([ 3, 1 ], [ 2, 0 ])

    assert_includes summary(second), "これでAlphaはBetaから7季連続で勝ち点を取った（1950年以降で最長）。"
  end

  test "and the runs it ended" do
    _first, second, third = season_with_alpha_beta([ 3, 1 ], [ 0, 2 ], [ 1, 4 ])

    assert_not_includes summary(second), "途切れた"
    assert_includes summary(third), "これでAlphaのBetaからの連続勝ち点は6季で途切れた。"
  end

  test "a run shorter than five seasons isn't shown" do
    seasons(3, order)
    target = season(2002, "autumn", order)

    assert_nil find(target, @alpha, "優勝")
  end

  test "before 1950 there are no runs" do
    assert_empty StreakRecords.new(Season.new(year: 1949, term: "spring")).records
  end
end
