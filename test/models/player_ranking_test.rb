require "test_helper"

class PlayerRankingTest < ActiveSupport::TestCase
  setup do
    @alpha = universities(:one)
    @beta = universities(:two)
    @spring = seasons(:one)
    @autumn = seasons(:two)
    @next_id = 40_000_000
  end

  def player(name, university: @alpha)
    Player.create!(scorebook_id: @next_id += 1, university: university, name: name, enter_year: 2023)
  end

  def game(season, number, counted: true)
    Game.create!(season: season, team0: @alpha, team1: @beta, played_on: "2026-05-#{number.to_s.rjust(2, '0')}", game_number: number, counted_in_stats: counted)
  end

  # One batting line: a season's worth in a single row (stats add up the same either way).
  def bat(player, game, **stats)
    BattingLine.create!({ game: game, player: player, university: player.university, pa: 30, ab: 27, hits: 9, walks: 3, total_bases: 12 }.merge(stats))
  end

  def pitch(player, game, **stats)
    PitchingLine.create!({ game: game, player: player, university: player.university, outs: 45, earned_runs: 5 }.merge(stats))
  end

  def names(ranking)
    ranking.entries.map { |entry| entry.player.name }
  end

  # ---- the minimum

  test "the default minimum is 40 for a career and 10 for a season, in plate appearances or innings" do
    assert_equal [ 40, 10 ], [ PlayerRanking.new("batting").minimum, PlayerRanking.new("batting", season: @spring).minimum ]
    assert_equal [ 40, 10 ], [ PlayerRanking.new("pitching").minimum, PlayerRanking.new("pitching", season: @spring).minimum ]
    assert_equal 40, PlayerRanking.default_minimum("pitching", season: nil)
    assert_equal 10, PlayerRanking.default_minimum("batting", season: @autumn)
  end

  test "a season ranks only batters with at least 10 plate appearances" do
    bat(player("十打席"), game(@spring, 1), pa: 10)
    bat(player("九打席"), game(@spring, 2), pa: 9)

    assert_equal %w[十打席], names(PlayerRanking.new("batting", season: @spring))
  end

  test "a career ranks only batters with at least 40 plate appearances, summed over all their games" do
    over = player("通算40")
    bat(over, game(@spring, 1), pa: 25)
    bat(over, game(@autumn, 2), pa: 15)
    bat(player("通算39"), game(@spring, 3), pa: 39)

    assert_equal %w[通算40], names(PlayerRanking.new("batting"))
    entry = PlayerRanking.new("batting").entries.sole
    assert_equal [ 2, 40 ], [ entry.totals.games, entry.totals.pa ]
  end

  test "a season ranks only pitchers with at least 10 innings" do
    pitch(player("十回"), game(@spring, 1), outs: 30)
    pitch(player("九回2/3"), game(@spring, 2), outs: 29)

    assert_equal %w[十回], names(PlayerRanking.new("pitching", season: @spring))
  end

  test "a career ranks only pitchers with at least 40 innings, summed over all their games" do
    over = player("四十回")
    pitch(over, game(@spring, 1), outs: 60)
    pitch(over, game(@autumn, 2), outs: 60)
    pitch(player("三十九回2/3"), game(@spring, 3), outs: 119)

    assert_equal %w[四十回], names(PlayerRanking.new("pitching"))
  end

  test "a minimum can be asked for, replacing the default: in plate appearances for batters, in innings for pitchers" do
    bat(player("二十五"), game(@spring, 1), pa: 25)
    bat(player("五十"), game(@spring, 2), pa: 50)
    pitch(player("五回"), game(@spring, 3), outs: 15)
    pitch(player("三十回"), game(@spring, 4), outs: 90)

    assert_equal %w[二十五 五十], names(PlayerRanking.new("batting", minimum: 25)).sort
    assert_equal %w[五十], names(PlayerRanking.new("batting", minimum: 26))
    assert_equal %w[三十回 五回], names(PlayerRanking.new("pitching", minimum: 5)).sort
    assert_equal %w[三十回], names(PlayerRanking.new("pitching", minimum: 6))
    assert_equal 25, PlayerRanking.new("batting", minimum: 25).minimum
  end

  test "a minimum of 0 ranks everyone with a rate, however few their plate appearances or innings" do
    bat(player("一打席"), game(@spring, 1), pa: 1, ab: 1, hits: 1, total_bases: 4)
    bat(player("レギュラー"), game(@spring, 2), pa: 120)
    pitch(player("一死"), game(@spring, 3), outs: 1, earned_runs: 0)

    assert_equal %w[一打席 レギュラー], names(PlayerRanking.new("batting", minimum: 0)) # 5.000 against a regular's rate
    assert_equal %w[一死], names(PlayerRanking.new("pitching", season: @spring, minimum: 0))
  end

  test "there is still no rate to rank for a batter with no OPS, or a pitcher with no ERA, whatever the minimum" do
    bat(player("打席なし"), game(@spring, 1), pa: 0, ab: 0)
    bat(player("打席あり"), game(@spring, 2), pa: 1, ab: 1, hits: 1, total_bases: 1)
    pitch(player("投げず"), game(@spring, 3), outs: 0, earned_runs: 0)
    pitch(player("投げた"), game(@spring, 4), outs: 3, earned_runs: 0)

    assert_equal %w[打席あり], names(PlayerRanking.new("batting", minimum: 0))
    assert_equal %w[投げた], names(PlayerRanking.new("pitching", minimum: 0))
  end

  test "minimum_from takes a whole number, and anything else is nil, so that the default applies" do
    assert_equal [ 25, 7, 0, 100_000 ], [ "25", " 7 ", "0", "999999999" ].map { |value| PlayerRanking.minimum_from(value) }
    assert_equal [ nil ] * 7, [ nil, "", " ", "abc", "-3", "2.5", "10打席" ].map { |value| PlayerRanking.minimum_from(value) }
  end

  test "a minimum too big to matter is limited" do
    assert_equal PlayerRanking::MAX_MINIMUM, PlayerRanking.new("batting", minimum: 10**12).minimum
  end

  # ---- OPS

  test "OPS ranks the highest first" do
    low = player("低い")
    bat(low, game(@spring, 1), ab: 27, hits: 5, walks: 3, total_bases: 6)
    high = player("高い")
    bat(high, game(@spring, 2), ab: 27, hits: 12, walks: 3, total_bases: 24)
    mid = player("中間")
    bat(mid, game(@spring, 3), ab: 27, hits: 9, walks: 3, total_bases: 12)

    assert_equal %w[高い 中間 低い], names(PlayerRanking.new("batting", season: @spring))
  end

  test "an entry carries the player and the summed totals" do
    ochiai = player("落合")
    bat(ochiai, game(@spring, 1), pa: 20, ab: 18, hits: 6, walks: 2, total_bases: 8)
    bat(ochiai, game(@spring, 2), pa: 15, ab: 14, hits: 4, walks: 1, total_bases: 6)

    entry = PlayerRanking.new("batting", season: @spring).entries.first

    assert_equal [ ochiai, 1 ], [ entry.player, entry.rank ]
    assert_equal [ 2, 35, 32, 10 ], entry.totals.to_h.values_at(:games, :pa, :ab, :hits)
    assert_in_delta (10 + 3) / 35.0 + 14 / 32.0, entry.totals.ops, 0.0001 # (H+BB)/(AB+BB) + TB/AB
  end

  test "a batter with plate appearances but no at-bats has no OPS and is left out" do
    bat(player("四球だけ"), game(@spring, 1), pa: 30, ab: 0, hits: 0, walks: 30, total_bases: 0)

    assert_empty PlayerRanking.new("batting", season: @spring).entries
  end

  test "equal displayed OPS shares a rank, the next rank skips, and more plate appearances comes first" do
    many = player("多い打席")
    bat(many, game(@spring, 1), pa: 40, ab: 27, hits: 9, walks: 3, total_bases: 12)
    few = player("少ない打席")
    bat(few, game(@spring, 2), pa: 30, ab: 27, hits: 9, walks: 3, total_bases: 12) # the same OPS
    lower = player("下")
    bat(lower, game(@spring, 3), pa: 30, ab: 27, hits: 2, walks: 3, total_bases: 2)

    entries = PlayerRanking.new("batting", season: @spring).entries

    assert_equal %w[多い打席 少ない打席 下], entries.map { |entry| entry.player.name }
    assert_equal [ 1, 1, 3 ], entries.map(&:rank)
  end

  # ---- ERA

  test "ERA ranks the lowest first" do
    good = player("好投")
    pitch(good, game(@spring, 1), outs: 90, earned_runs: 3)
    bad = player("打たれた")
    pitch(bad, game(@spring, 2), outs: 90, earned_runs: 30)
    mid = player("平均")
    pitch(mid, game(@spring, 3), outs: 90, earned_runs: 10)

    assert_equal %w[好投 平均 打たれた], names(PlayerRanking.new("pitching", season: @spring))
  end

  test "a pitcher entry carries the summed totals and an earned run average of nine-inning runs" do
    ito = player("伊藤")
    pitch(ito, game(@spring, 1), outs: 27, earned_runs: 1, wins: 1)
    pitch(ito, game(@spring, 2), outs: 27, earned_runs: 3, losses: 1)

    entry = PlayerRanking.new("pitching", season: @spring).entries.first

    assert_equal [ 2, 54, 4, 1, 1 ], entry.totals.to_h.values_at(:games, :outs, :earned_runs, :wins, :losses)
    assert_in_delta 2.0, entry.totals.era, 0.0001 # 4 earned runs in 18 innings
  end

  test "equal displayed ERA shares a rank and the pitcher with more innings comes first" do
    long = player("長い")
    pitch(long, game(@spring, 1), outs: 90, earned_runs: 10)
    short = player("短い")
    pitch(short, game(@spring, 2), outs: 45, earned_runs: 5)   # same 3.33 as long
    worse = player("悪い")
    pitch(worse, game(@spring, 3), outs: 45, earned_runs: 9)

    entries = PlayerRanking.new("pitching", season: @spring).entries

    assert_equal %w[長い 短い 悪い], entries.map { |entry| entry.player.name }
    assert_equal [ 1, 1, 3 ], entries.map(&:rank)
  end

  # ---- period, games, and universities

  test "a season ranks only what was done in that season" do
    both = player("両シーズン")
    bat(both, game(@spring, 1), pa: 30, ab: 27, hits: 20, walks: 3, total_bases: 40)
    bat(both, game(@autumn, 2), pa: 30, ab: 27, hits: 2, walks: 3, total_bases: 2)

    spring = PlayerRanking.new("batting", season: @spring).entries.first.totals
    autumn = PlayerRanking.new("batting", season: @autumn).entries.first.totals

    assert_operator spring.ops, :>, autumn.ops
    assert_equal [ 1, 1 ], [ spring.games, autumn.games ]
  end

  test "games not counted toward stats add nothing: a player with only those is not ranked, another's totals leave them out" do
    bat(player("決定戦だけ"), game(@spring, 1, counted: false), pa: 40)
    mixed = player("両方")
    bat(mixed, game(@spring, 2), pa: 25)
    bat(mixed, game(@spring, 3, counted: false), pa: 40)

    ranking = PlayerRanking.new("batting", season: @spring)

    assert_equal %w[両方], names(ranking)
    assert_equal 25, ranking.entries.sole.totals.pa
  end

  test "a university filter limits the ranking to those universities, and an empty list to nobody" do
    bat(player("アルファ", university: @alpha), game(@spring, 1))
    bat(player("ベータ", university: @beta), game(@spring, 2))

    assert_equal %w[ベータ], names(PlayerRanking.new("batting", season: @spring, university_ids: [ @beta.id ]))
    assert_equal 2, PlayerRanking.new("batting", season: @spring, university_ids: [ @alpha.id, @beta.id ]).entries.size
    assert_equal 2, PlayerRanking.new("batting", season: @spring, university_ids: nil).entries.size
    assert_empty PlayerRanking.new("batting", season: @spring, university_ids: []).entries
  end

  test "an unknown kind is rejected" do
    assert_raises(ArgumentError) { PlayerRanking.new("avg") }
  end

  # ---- seasons_with_stats

  test "seasons_with_stats lists the seasons that have counted stats of that kind, newest first" do
    bat(player("春の打者"), game(@spring, 1))
    bat(player("秋の打者"), game(@autumn, 2))
    pitch(player("春の投手"), game(@spring, 3))

    assert_equal [ @autumn, @spring ], PlayerRanking.seasons_with_stats("batting").to_a
    assert_equal [ @spring ], PlayerRanking.seasons_with_stats("pitching").to_a
  end

  test "a season with stats only from games not counted is not offered" do
    bat(player("決定戦だけ"), game(@autumn, 1, counted: false))

    assert_empty PlayerRanking.seasons_with_stats("batting")
  end

  # ---- sorting by a column

  def sortable_ranking(kind = "batting")
    PlayerRanking.new(kind, season: @spring)
  end

  test "sorting reorders the rows and numbers them again in the new order, keeping the OPS rank as default_rank" do
    top = player("一位")
    bat(top, game(@spring, 1), pa: 30, ab: 27, hits: 15, walks: 3, total_bases: 30)
    busy = player("打席多い")
    bat(busy, game(@spring, 2), pa: 60, ab: 54, hits: 10, walks: 6, total_bases: 14)

    sorted = sortable_ranking.entries_sorted_by("pa")

    assert_equal %w[打席多い 一位], sorted.map { |entry| entry.player.name }
    assert_equal [ 1, 2 ], sorted.map(&:rank)      # numbered in the order shown
    assert_equal [ 2, 1 ], sorted.map(&:default_rank) # the rank by OPS
    assert_equal %w[一位 打席多い], sortable_ranking.entries.map { |entry| entry.player.name } # the ranking itself is unchanged
  end

  test "an unsorted entry's default_rank is its rank" do
    bat(player("選手"), game(@spring, 1))

    entry = sortable_ranking.entries.first

    assert_equal [ 1, 1 ], [ entry.rank, entry.default_rank ]
  end

  test "equal values in the sorted column share a number and the next one skips" do
    [ [ "同じ一", 40 ], [ "同じ二", 40 ], [ "少ない", 30 ] ].each_with_index do |(name, pa), index|
      bat(player(name), game(@spring, index + 1), pa: pa)
    end

    assert_equal [ 1, 1, 3 ], sortable_ranking.entries_sorted_by("pa", "desc").map(&:rank)
    assert_equal [ 1, 2, 2 ], sortable_ranking.entries_sorted_by("pa", "asc").map(&:rank)
  end

  test "ascending order numbers from the smallest" do
    bat(player("小"), game(@spring, 1), pa: 30)
    bat(player("大"), game(@spring, 2), pa: 50)

    assert_equal [ [ "小", 1 ], [ "大", 2 ] ], sortable_ranking.entries_sorted_by("pa", "asc").map { |e| [ e.player.name, e.rank ] }
    assert_equal [ [ "大", 1 ], [ "小", 2 ] ], sortable_ranking.entries_sorted_by("pa", "desc").map { |e| [ e.player.name, e.rank ] }
  end

  test "rates share a number when they are equal as displayed, to three decimals" do
    a = player("A")
    bat(a, game(@spring, 1), ab: 1000, hits: 300) # .300
    b = player("B")
    bat(b, game(@spring, 2), ab: 1000, hits: 300) # .300
    c = player("C")
    bat(c, game(@spring, 3), ab: 1000, hits: 299) # .299

    assert_equal [ 1, 1, 3 ], sortable_ranking.entries_sorted_by("average").map(&:rank)
  end

  test "names and universities are numbered one by one, without ties" do
    2.times { |i| bat(player("同じ大学#{i}", university: @alpha), game(@spring, i + 1)) }

    assert_equal [ 1, 2 ], sortable_ranking.entries_sorted_by("university").map(&:rank)
    assert_equal [ 1, 2 ], sortable_ranking.entries_sorted_by("player").map(&:rank)
  end

  test "sorting by rank keeps the ranking's own ranks, in either direction" do
    [ 15, 12, 9 ].each_with_index { |hits, index| bat(player("選手#{index}"), game(@spring, index + 1), hits: hits, total_bases: hits + 3) }

    assert_equal [ 1, 2, 3 ], sortable_ranking.entries_sorted_by("rank").map(&:rank)
    assert_equal [ 3, 2, 1 ], sortable_ranking.entries_sorted_by("rank", "desc").map(&:rank)
  end

  test "a column starts with the largest first, except rank, names, universities and ERA" do
    assert_equal "desc", PlayerRanking.default_direction("batting", "ops")
    assert_equal "desc", PlayerRanking.default_direction("batting", "pa")
    assert_equal "desc", PlayerRanking.default_direction("pitching", "wins")
    assert_equal "asc", PlayerRanking.default_direction("pitching", "era")
    assert_equal "asc", PlayerRanking.default_direction("batting", "rank")
    assert_equal "asc", PlayerRanking.default_direction("batting", "player")
    assert_equal "asc", PlayerRanking.default_direction("pitching", "university")
  end

  test "an explicit direction overrides the default" do
    small = player("小")
    bat(small, game(@spring, 1), pa: 30)
    large = player("大")
    bat(large, game(@spring, 2), pa: 50)

    assert_equal %w[大 小], sortable_ranking.entries_sorted_by("pa", "desc").map { |e| e.player.name }
    assert_equal %w[小 大], sortable_ranking.entries_sorted_by("pa", "asc").map { |e| e.player.name }
    assert_equal %w[大 小], sortable_ranking.entries_sorted_by("pa").map { |e| e.player.name }
  end

  test "ties in the sorted column stay in rank order, whichever way it is sorted" do
    a = player("高い同じ打席")
    bat(a, game(@spring, 1), pa: 40, ab: 27, hits: 15, walks: 3, total_bases: 25)
    b = player("低い同じ打席")
    bat(b, game(@spring, 2), pa: 40, ab: 27, hits: 5, walks: 3, total_bases: 6)

    assert_equal %w[高い同じ打席 低い同じ打席], sortable_ranking.entries_sorted_by("pa", "desc").map { |e| e.player.name }
    assert_equal %w[高い同じ打席 低い同じ打席], sortable_ranking.entries_sorted_by("pa", "asc").map { |e| e.player.name }
  end

  test "names sort by their text and universities in the league's order" do
    beta = player("あ", university: @beta)
    bat(beta, game(@spring, 1))
    alpha = player("い", university: @alpha)
    bat(alpha, game(@spring, 2))

    assert_equal %w[あ い], sortable_ranking.entries_sorted_by("player").map { |e| e.player.name }
    assert_equal [ @alpha, @beta ].sort_by(&:position).map(&:id), sortable_ranking.entries_sorted_by("university").map { |e| e.player.university_id }
  end

  test "an ERA ranking sorts by its own columns" do
    winner = player("勝ち頭")
    pitch(winner, game(@spring, 1), outs: 90, earned_runs: 20, wins: 5)
    stingy = player("防御率良い")
    pitch(stingy, game(@spring, 2), outs: 90, earned_runs: 2, wins: 1)

    assert_equal %w[防御率良い 勝ち頭], sortable_ranking("pitching").entries.map { |e| e.player.name }
    assert_equal %w[勝ち頭 防御率良い], sortable_ranking("pitching").entries_sorted_by("wins").map { |e| e.player.name }
    assert_equal %w[防御率良い 勝ち頭], sortable_ranking("pitching").entries_sorted_by("wins", "asc").map { |e| e.player.name }
  end

  test "blank values sort last whichever way the column is sorted" do
    ranking = sortable_ranking
    entry = ->(rank, name, ab, hits) { PlayerRanking::Entry.new(rank, Player.new(name: name), BattingLine::Totals.new(games: 1, ab: ab, hits: hits)) }
    ranking.define_singleton_method(:entries) { [ entry.call(1, "打率3割", 10, 3), entry.call(2, "打数なし", 0, 0), entry.call(3, "打率2割", 10, 2) ] }

    assert_equal %w[打率3割 打率2割 打数なし], ranking.entries_sorted_by("average", "desc").map { |e| e.player.name }
    assert_equal %w[打率2割 打率3割 打数なし], ranking.entries_sorted_by("average", "asc").map { |e| e.player.name }
  end

  test "an unknown sort column is rejected" do
    assert_raises(KeyError) { sortable_ranking.entries_sorted_by("wins") } # an ERA column, not an OPS one
    assert_raises(KeyError) { PlayerRanking.default_direction("batting", "nope") }
  end

  test "every kind lists its sortable columns in table order" do
    assert_equal %w[rank player university ops average obp slg games pa ab hits home_runs], PlayerRanking.sort_keys("batting")
    assert_equal %w[rank player university era games outs wins losses hits strikeouts walks earned_runs], PlayerRanking.sort_keys("pitching")
  end
end
