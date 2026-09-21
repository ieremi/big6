require "test_helper"

class Api::V1::RankingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @alpha = universities(:one)
    @beta = universities(:two)
    @spring = seasons(:one)
    @autumn = seasons(:two)
    @next_id = 60_000_000
  end

  def player(name, university: @alpha)
    Player.create!(scorebook_id: @next_id += 1, university: university, name: name, enter_year: 2023)
  end

  def game(season, number)
    Game.create!(season: season, team0: @alpha, team1: @beta, played_on: "2026-05-#{number.to_s.rjust(2, '0')}", game_number: number)
  end

  def bat(player, game, **stats)
    BattingLine.create!({ game: game, player: player, university: player.university, pa: 30, ab: 27, hits: 9, walks: 3, total_bases: 12 }.merge(stats))
  end

  def pitch(player, game, **stats)
    PitchingLine.create!({ game: game, player: player, university: player.university, outs: 45, earned_runs: 5 }.merge(stats))
  end

  def json
    JSON.parse(response.body)
  end

  def names
    json["rankings"].map { |row| row["player"]["name"] }
  end

  test "ops returns the ranking with the season and each batter's rates" do
    ochiai = player("落合")
    bat(ochiai, game(@spring, 1), pa: 40, ab: 32, hits: 16, walks: 8, total_bases: 24)
    bat(player("下位"), game(@spring, 2), hits: 3, total_bases: 3)

    get api_v1_ranking_url("batting"), params: { year: 2026, term: "spring" }

    assert_response :success
    assert_equal({ "year" => 2026, "term" => "spring", "title" => "2026年春季" }, json["season"])
    assert_equal({ "plate_appearances" => 10 }, json["minimum"]) # a season's default
    assert_equal [ "batting", 2, 1, 100 ], [ json["kind"], json["total"], json["page"], json["per_page"] ]
    assert_equal %w[落合 下位], names

    first = json["rankings"].first
    assert_equal [ 1, 1, { "id" => ochiai.scorebook_id, "name" => "落合", "university" => @alpha.slug } ], first.values_at("rank", "default_rank", "player")
    assert_in_delta 0.5, first["average"], 0.0001           # 16 / 32
    assert_in_delta 24 / 40.0, first["obp"], 0.0001         # (16 + 8) / (32 + 8)
    assert_in_delta 0.75, first["slg"], 0.0001              # 24 / 32
    assert_in_delta 24 / 40.0 + 0.75, first["ops"], 0.0001
    assert_equal [ 1, 40, 32, 16, 24 ], first.values_at("games", "pa", "ab", "hits", "total_bases")
  end

  test "the minimum is 40 for a career and 10 for a season, in plate appearances or innings, unless asked for" do
    get api_v1_ranking_url("batting")
    assert_equal({ "plate_appearances" => 40 }, json["minimum"])

    get api_v1_ranking_url("pitching")
    assert_equal({ "innings" => 40 }, json["minimum"])

    get api_v1_ranking_url("pitching"), params: { year: 2026, term: "spring" }
    assert_equal({ "innings" => 10 }, json["minimum"])
  end

  test "minimum sets the least plate appearances or innings to be ranked, and 0 is no minimum" do
    bat(player("二十"), game(@spring, 1), pa: 20)
    bat(player("五十"), game(@spring, 2), pa: 50)
    bat(player("一"), game(@spring, 3), pa: 1)
    pitch(player("六回"), game(@spring, 4), outs: 18)

    get api_v1_ranking_url("batting"), params: { minimum: 20 }
    assert_equal [ { "plate_appearances" => 20 }, %w[二十 五十] ], [ json["minimum"], names.sort ]

    get api_v1_ranking_url("batting"), params: { minimum: 0 }
    assert_equal({ "plate_appearances" => 0 }, json["minimum"])
    assert_equal 3, json["total"]

    get api_v1_ranking_url("pitching"), params: { minimum: 6 }
    assert_equal [ { "innings" => 6 }, %w[六回] ], [ json["minimum"], names ]

    get api_v1_ranking_url("pitching"), params: { minimum: 7 }
    assert_equal 0, json["total"]
  end

  test "a minimum that is not a whole number is the default" do
    bat(player("選手"), game(@spring, 1), pa: 100)

    [ "abc", "-1", "1.5", "" ].each do |value|
      get api_v1_ranking_url("batting"), params: { minimum: value }

      assert_equal({ "plate_appearances" => 40 }, json["minimum"], value.inspect)
      assert_equal %w[選手], names
    end
  end

  test "era returns the ranking lowest first, in innings and nine-inning runs" do
    ito = player("伊藤")
    pitch(ito, game(@spring, 1), outs: 151, earned_runs: 6, wins: 1)
    pitch(player("打たれた"), game(@spring, 2), outs: 90, earned_runs: 30, losses: 1)

    get api_v1_ranking_url("pitching"), params: { year: 2026, term: "spring" }

    assert_response :success
    assert_equal %w[伊藤 打たれた], names

    first = json["rankings"].first
    assert_equal [ 1, 151, "50 1/3", 6, 1 ], first.values_at("rank", "outs", "innings", "earned_runs", "wins")
    assert_in_delta 6 * 27.0 / 151, first["era"], 0.0001
  end

  test "without a season the ranking is over the whole career, and season is null" do
    over = player("通算")
    bat(over, game(@spring, 1), pa: 120)
    bat(over, game(@autumn, 2), pa: 80)

    get api_v1_ranking_url("batting")

    assert_nil json["season"]
    assert_equal %w[通算], names
    assert_equal 2, json["rankings"].first["games"]
  end

  test "university filters by slug, several are allowed, and an unknown slug leaves nobody" do
    bat(player("アルファ", university: @alpha), game(@spring, 1))
    bat(player("ベータ", university: @beta), game(@spring, 2))
    params = { year: 2026, term: "spring" }

    get api_v1_ranking_url("batting"), params: params.merge(university: [ @beta.slug ])
    assert_equal %w[ベータ], names

    get api_v1_ranking_url("batting"), params: params.merge(university: [ @alpha.slug, @beta.slug ])
    assert_equal 2, json["total"]

    get api_v1_ranking_url("batting"), params: params.merge(university: [ "nowhere" ])
    assert_response :success
    assert_equal 0, json["total"]
  end

  test "equal values share a rank" do
    bat(player("同じ一"), game(@spring, 1))
    bat(player("同じ二"), game(@spring, 2))
    bat(player("下"), game(@spring, 3), hits: 1, total_bases: 1)

    get api_v1_ranking_url("batting"), params: { year: 2026, term: "spring" }

    assert_equal [ 1, 1, 3 ], json["rankings"].map { |row| row["rank"] }
  end

  test "it pages through the results 100 at a time" do
    (1..101).each { |i| bat(player("選手#{i.to_s.rjust(3, '0')}"), game(@spring, i % 28 + 1), total_bases: 12 + i, pa: 30) }

    get api_v1_ranking_url("batting"), params: { year: 2026, term: "spring" }
    assert_equal [ 101, 1, 100 ], [ json["total"], json["page"], json["rankings"].size ]

    get api_v1_ranking_url("batting"), params: { year: 2026, term: "spring", page: 2 }
    assert_equal [ 2, 1 ], [ json["page"], json["rankings"].size ]
    assert_equal 101, json["rankings"].first["rank"]
  end

  test "an unknown season is a JSON 404" do
    get api_v1_ranking_url("batting"), params: { year: 1900, term: "spring" }

    assert_response :not_found
    assert_equal({ "error" => "not found" }, json)
  end

  test "a kind that is not ops or era is not a route" do
    get "/api/v1/rankings/avg"

    assert_response :not_found
  end

  test "a year without a term ranks the career" do
    bat(player("通算"), game(@spring, 1), pa: 250)

    get api_v1_ranking_url("batting"), params: { year: 2026 }

    assert_nil json["season"]
    assert_equal %w[通算], names
  end

  # ---- sorting

  def add_batters_of_different_size
    bat(player("一位"), game(@spring, 1), pa: 30, ab: 27, hits: 15, walks: 3, total_bases: 30)
    bat(player("二位"), game(@spring, 2), pa: 45, ab: 40, hits: 14, walks: 5, total_bases: 20)
    bat(player("三位"), game(@spring, 3), pa: 60, ab: 54, hits: 10, walks: 6, total_bases: 14)
  end

  test "the response says how it is sorted, by rank unless asked otherwise" do
    add_batters_of_different_size

    get api_v1_ranking_url("batting"), params: { year: 2026, term: "spring" }

    assert_equal [ "rank", "asc" ], json.values_at("sort", "direction")
    assert_equal %w[一位 二位 三位], names
  end

  test "sort and direction reorder the rows and rank is the position in that order" do
    add_batters_of_different_size

    get api_v1_ranking_url("batting"), params: { year: 2026, term: "spring", sort: "pa", direction: "desc" }

    assert_equal [ "pa", "desc" ], json.values_at("sort", "direction")
    assert_equal %w[三位 二位 一位], names
    assert_equal [ 1, 2, 3 ], json["rankings"].map { |row| row["rank"] }           # numbered in the sorted order
    assert_equal [ 3, 2, 1 ], json["rankings"].map { |row| row["default_rank"] }       # the rank by OPS
  end

  test "a column starts largest first unless it is rank, player, university, or era" do
    add_batters_of_different_size

    get api_v1_ranking_url("batting"), params: { year: 2026, term: "spring", sort: "pa" }
    assert_equal [ "pa", "desc" ], json.values_at("sort", "direction")

    get api_v1_ranking_url("batting"), params: { year: 2026, term: "spring", sort: "player" }
    assert_equal [ "player", "asc" ], json.values_at("sort", "direction")
  end

  test "the era ranking sorts by its own columns" do
    pitch(player("勝ち頭"), game(@spring, 1), outs: 90, earned_runs: 20, wins: 5)
    pitch(player("防御率良い"), game(@spring, 2), outs: 90, earned_runs: 2, wins: 1)

    get api_v1_ranking_url("pitching"), params: { year: 2026, term: "spring", sort: "wins" }

    assert_equal %w[勝ち頭 防御率良い], names
    assert_equal [ 1, 2 ], json["rankings"].map { |row| row["rank"] }
    assert_equal [ 2, 1 ], json["rankings"].map { |row| row["default_rank"] }
  end

  test "an invalid sort or direction, or another ranking's column, is ignored" do
    add_batters_of_different_size

    [ { sort: "bogus" }, { sort: "wins" }, { direction: "sideways" }, { sort: "pa", direction: "sideways" } ].each do |extra|
      get api_v1_ranking_url("batting"), params: { year: 2026, term: "spring" }.merge(extra)

      assert_response :success, extra.inspect
      expected_sort = extra[:sort] == "pa" ? "pa" : "rank"
      assert_equal expected_sort, json["sort"], extra.inspect
    end
  end

  test "the sort is applied before paging" do
    (1..101).each { |i| bat(player("選手#{i.to_s.rjust(3, '0')}"), game(@spring, i % 28 + 1), pa: 200 - i, total_bases: 12 + i) }

    get api_v1_ranking_url("batting"), params: { year: 2026, term: "spring", sort: "pa", direction: "asc", page: 2 }

    assert_equal 1, json["rankings"].size
    assert_equal "選手001", names.first # the most plate appearances comes last in ascending order
  end
  test "sorting by rank keeps the ranks by OPS, and equal values in another column share a rank" do
    bat(player("同じ一"), game(@spring, 1), pa: 40)
    bat(player("同じ二"), game(@spring, 2), pa: 40)
    bat(player("少ない"), game(@spring, 3), pa: 30, hits: 1, total_bases: 1)

    get api_v1_ranking_url("batting"), params: { year: 2026, term: "spring", sort: "pa" }
    assert_equal [ 1, 1, 3 ], json["rankings"].map { |row| row["rank"] }

    get api_v1_ranking_url("batting"), params: { year: 2026, term: "spring", sort: "rank", direction: "desc" }
    assert_equal [ 3, 1, 1 ], json["rankings"].map { |row| row["rank"] }
    assert_equal [ 3, 1, 1 ], json["rankings"].map { |row| row["default_rank"] }
  end
end
