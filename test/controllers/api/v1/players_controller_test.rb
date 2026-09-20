require "test_helper"

class Api::V1::PlayersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @alpha = universities(:one)
    @beta = universities(:two)
    @ochiai = create_player(20236010, @alpha, "落合 智哉", name_kana: "オチアイ トモヤ", enter_year: 2023, position: "捕手", high_school: "東邦")
    @imazu = create_player(20231007, @beta, "今津 慶介", name_kana: "イマヅ ケイスケ", enter_year: 2023, position: "遊撃手")
    @old = create_player(19951001, @alpha, "山田 太郎", enter_year: 1995, enrollment_status: 2)
    @coach = create_player(19951099, @alpha, "日野 愛郎", enter_year: nil, role: "部長", enrollment_status: 3)
  end

  def create_player(scorebook_id, university, name, **attributes)
    Player.create!({ scorebook_id: scorebook_id, university: university, name: name, enter_year: 2023, role: "選手", enrollment_status: 1 }.merge(attributes))
  end

  def json
    JSON.parse(response.body)
  end

  def ids
    json["players"].map { |player| player["id"] }
  end

  # ---- index

  test "index returns the page, the total, and each player's profile" do
    get api_v1_players_url

    assert_response :success
    assert_equal [ 4, 1, 100 ], [ json["total"], json["page"], json["per_page"] ]
    ochiai = json["players"].find { |player| player["id"] == 20236010 }
    assert_equal({ "id" => 20236010, "name" => "落合 智哉", "name_kana" => "オチアイ トモヤ", "university" => @alpha.slug, "enter_year" => 2023,
                   "role" => "選手", "position" => "捕手", "batting_hand" => nil, "pitching_hand" => nil, "high_school" => "東邦",
                   "faculty" => nil, "grade" => nil, "status" => "active", "og_image_url" => api_v1_player_og_image_url(@ochiai) }, ochiai)
  end

  test "index puts the newest entry year first and players without one last" do
    get api_v1_players_url

    assert_equal [ 20236010, 20231007, 19951001, 19951099 ], ids
  end

  test "index filters by keyword, university slug, entry year, role, and status" do
    get api_v1_players_url, params: { q: "落合智哉" }
    assert_equal [ 20236010 ], ids

    get api_v1_players_url, params: { university: [ @beta.slug ] }
    assert_equal [ 20231007 ], ids

    get api_v1_players_url, params: { start_year: 1990, end_year: 2000 }
    assert_equal [ 19951001 ], ids

    get api_v1_players_url, params: { role: "staff" }
    assert_equal [ 19951099 ], ids

    get api_v1_players_url, params: { status: "alumni" }
    assert_equal [ 19951001 ], ids
  end

  test "index accepts several universities" do
    get api_v1_players_url, params: { university: [ @alpha.slug, @beta.slug ], start_year: 2023 }

    assert_equal [ 20236010, 20231007 ], ids
  end

  test "index returns nobody for a university slug that does not exist" do
    get api_v1_players_url, params: { university: [ "nowhere" ] }

    assert_response :success
    assert_equal 0, json["total"]
    assert_empty json["players"]
  end

  test "index ignores unknown role and status values" do
    get api_v1_players_url, params: { role: "bogus", status: "bogus" }

    assert_equal 4, json["total"]
  end

  test "index pages through the results 100 at a time" do
    Player.where.not(id: @ochiai.id).delete_all
    (1..100).each { |i| create_player(30000000 + i, @alpha, "選手#{i.to_s.rjust(3, '0')}", enter_year: 2020) }

    get api_v1_players_url
    assert_equal [ 101, 1, 100 ], [ json["total"], json["page"], json["players"].size ]

    get api_v1_players_url, params: { page: 2 }
    assert_equal [ 2, 1 ], [ json["page"], json["players"].size ]
    assert_equal "選手100", json["players"].first["name"]
  end

  # ---- show

  test "show returns the profile with null stats for a player who has none" do
    get api_v1_player_url(@ochiai)

    assert_response :success
    assert_equal [ 20236010, "落合 智哉", "active" ], json.values_at("id", "name", "status")
    assert_nil json["batting"]
    assert_nil json["pitching"]
  end

  test "show reports a graduate as alumni and someone who left as null" do
    get api_v1_player_url(@old)
    assert_equal "alumni", json["status"]

    get api_v1_player_url(@coach)
    assert_nil json["status"]
    assert_nil json["enter_year"]
  end

  test "show returns season and career stats, leaving out games not counted" do
    spring = Game.create!(season: seasons(:one), team0: @alpha, team1: @beta, played_on: "2026-05-02", game_number: 1)
    autumn = Game.create!(season: seasons(:two), team0: @alpha, team1: @beta, played_on: "2026-09-20", game_number: 1)
    playoff = Game.create!(season: seasons(:one), team0: @alpha, team1: @beta, played_on: "2026-06-04", game_number: 5, counted_in_stats: false)
    BattingLine.create!(game: spring, player: @ochiai, university: @alpha, pa: 4, ab: 4, hits: 2, home_runs: 1, rbi: 3)
    BattingLine.create!(game: autumn, player: @ochiai, university: @alpha, pa: 4, ab: 4, hits: 1)
    BattingLine.create!(game: playoff, player: @ochiai, university: @alpha, pa: 5, ab: 5, hits: 5)
    PitchingLine.create!(game: spring, player: @ochiai, university: @alpha, outs: 10, earned_runs: 3, strikeouts: 4, losses: 1, started: 1)

    get api_v1_player_url(@ochiai)

    batting = json["batting"]
    assert_equal [ [ 2026, "spring", 1 ], [ 2026, "autumn", 1 ] ], batting["seasons"].map { |row| row.values_at("year", "term", "games") }
    assert_in_delta 0.5, batting["seasons"].first["average"], 0.0001
    assert_equal [ 2, 8, 3, 1, 3 ], batting["career"].values_at("games", "ab", "hits", "home_runs", "rbi")
    assert_in_delta 0.375, batting["career"]["average"], 0.0001

    pitching = json["pitching"]
    assert_equal [ 1, 10, "3 1/3", 3, 4, 1, 1, 0 ], pitching["career"].values_at("games", "outs", "innings", "earned_runs", "strikeouts", "started", "losses", "wins")
    assert_in_delta 8.1, pitching["career"]["era"], 0.0001
  end

  test "show returns 404 as JSON for an unknown player" do
    get api_v1_player_url(id: 1)

    assert_response :not_found
    assert_equal({ "error" => "not found" }, json)
  end

  test "a player id that is not a number is not a route" do
    get "/api/v1/players/abc"

    assert_response :not_found
  end

  test "show gives on-base, slugging, OPS, and total bases with the batting average" do
    game = Game.create!(season: seasons(:one), team0: @alpha, team1: @beta, played_on: "2026-05-02", game_number: 1)
    BattingLine.create!(game: game, player: @ochiai, university: @alpha, pa: 5, ab: 4, hits: 2, doubles: 1, total_bases: 3, walks: 1)

    get api_v1_player_url(@ochiai)

    [ json["batting"]["career"], json["batting"]["seasons"].first ].each do |totals|
      assert_in_delta 0.5, totals["average"], 0.0001    # 2 / 4
      assert_in_delta 0.6, totals["obp"], 0.0001        # (2 + 1) / (4 + 1)
      assert_in_delta 0.75, totals["slg"], 0.0001       # 3 / 4
      assert_in_delta 1.35, totals["ops"], 0.0001
      assert_equal 3, totals["total_bases"]
    end
  end

  test "games includes the total bases of each batting line" do
    game = Game.create!(season: seasons(:one), team0: @alpha, team1: @beta, played_on: "2026-05-02", game_number: 1)
    BattingLine.create!(game: game, player: @ochiai, university: @alpha, hits: 2, doubles: 1, total_bases: 3)

    get api_v1_player_games_url(@ochiai)

    assert_equal 3, json.first["batting"]["total_bases"]
  end

  # ---- games

  test "games merges the roster entry, batting line, and pitching line of each game, newest first" do
    first = Game.create!(season: seasons(:one), team0: @alpha, team1: @beta, played_on: "2026-05-02", game_number: 1)
    second = Game.create!(season: seasons(:one), team0: @beta, team1: @alpha, played_on: "2026-05-09", game_number: 2, counted_in_stats: false)
    GameMember.create!(game: first, player: @ochiai, university: @alpha, uniform_number: 27, grade: 3, role: "捕手", batting_order: 5, fielding_position: "捕")
    BattingLine.create!(game: first, player: @ochiai, university: @alpha, position: "[捕]", pa: 4, ab: 3, hits: 2, walks: 1)
    PitchingLine.create!(game: first, player: @ochiai, university: @alpha, outs: 3, started: 0, wins: 1)
    BattingLine.create!(game: second, player: @ochiai, university: @alpha, pa: 4, ab: 4, hits: 4)

    get api_v1_player_games_url(@ochiai)

    assert_response :success
    assert_equal [ "2026-05-09", "2026-05-02" ], json.map { |entry| entry["game"]["played_on"] }

    newer, older = json
    assert_equal @beta.slug, newer["game"]["team0"]
    assert_equal false, newer["counted_in_stats"]
    assert_nil newer["roster"]
    assert_nil newer["pitching"]
    assert_equal @beta.slug, newer["opponent"]
    assert_equal 4, newer["batting"]["hits"]

    assert_equal({ "year" => 2026, "term" => "spring", "team0" => @alpha.slug, "team1" => @beta.slug, "round" => 1, "played_on" => "2026-05-02" }, older["game"])
    assert_equal @beta.slug, older["opponent"]
    assert_equal true, older["counted_in_stats"]
    assert_equal({ "uniform_number" => 27, "grade" => 3, "role" => "捕手", "batting_order" => 5, "fielding_position" => "捕" }, older["roster"])
    assert_equal [ "[捕]", 4, 3, 2, 1 ], older["batting"].values_at("position", "pa", "ab", "hits", "walks")
    assert_equal [ 3, "1", false, "win" ], [ older["pitching"]["outs"], older["pitching"]["innings"], older["pitching"]["started"], older["pitching"]["result"] ]
  end

  test "games is an empty list for a player with no games" do
    get api_v1_player_games_url(@imazu)

    assert_response :success
    assert_equal [], json
  end

  test "games returns 404 for an unknown player" do
    get api_v1_player_games_url(id: 1)

    assert_response :not_found
  end

  # ---- og_image

  test "og_image returns the player's PNG" do
    get api_v1_player_og_image_url(@ochiai)

    assert_response :success
    assert_equal "image/png", response.media_type
    assert_equal "\x89PNG".b, response.body.b[0, 4]
  end

  test "og_image returns 404 for an unknown player" do
    get api_v1_player_og_image_url(id: 1)

    assert_response :not_found
  end
end
