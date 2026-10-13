require "test_helper"

class GameSummaryTest < ActiveSupport::TestCase
  setup do
    @alpha = universities(:one) # team0: the visitor, batting first
    @beta = universities(:two)  # team1: the home side
    @season = seasons(:one)
    Game.delete_all
    @details = []
  end

  # A final game with Scorebook's scoreboard: innings is [[top, bottom], ...].
  def game(day, number, team0_score, team1_score, innings: [ %w[0 0] ] * 9, **attributes)
    id = 2026040000 + @details.size + 1
    @details << { "id" => id, "stadium" => "神宮球場", "attendance" => "8,000 " }
      .merge(innings.each_with_index.flat_map { |(top, bottom), i| [ [ "runs#{i + 1}Top", top ], [ "runs#{i + 1}Bottom", bottom ] ] }.to_h)
    @season.update!(scorebook_games: @details)
    Game.create!({ season: @season, team0: @alpha, team1: @beta, played_on: day, game_number: number, team0_score: team0_score, team1_score: team1_score,
      game_status: "試合終了", scorebook_game_id: id, duration_minutes: 175 }.merge(attributes))
  end

# A game still to play in Scorebook's data, so the season isn't over.
def pending_game_left
  @season.update!(scorebook_games: @details + [ { "id" => 1, "gameStatus" => "試合前" } ])
end

  def summary(game)
    GameSummary.new(game.reload, scoreboard: GameScoreboard.new(game)).to_s
  end

  def player(id, name, university)
    Player.create!(scorebook_id: id, university: university, name: name, role: "選手")
  end

  test "tells the result, where and when, the crowd and the time, and where the card stands" do
    first = game("2026-04-11", 1, 4, 2)
    pending_game_left

    assert_equal "2026年4月11日（土）、神宮球場で行われた東京六大学野球 2026年春季リーグ戦 第1回戦は、#{@alpha.short_name}が#{@beta.short_name}に4-2で勝った。" \
      "観衆は8,000人、試合時間は2時間55分。これでこのカードは#{@alpha.short_name}の1勝0敗。" \
      "残りの試合の勝敗を五分とした優勝確率は、#{@alpha.short_name}が50%から75%に上がり、#{@beta.short_name}が50%から25%に下がった。", summary(first)

    second = game("2026-04-12", 2, 1, 3)
    assert_match "#{@beta.short_name}が#{@alpha.short_name}に3-1で勝った。", summary(second)
    assert_match "これでこのカードは1勝1敗の五分。", summary(second)
  end

  test "names the winning and losing pitchers and the home runs" do
    first = game("2026-04-11", 1, 4, 2)
    PitchingLine.create!(game: first, player: player(1, "渡辺 和大", @alpha), university: @alpha, outs: 27, wins: 1)
    PitchingLine.create!(game: first, player: player(2, "南 陽人", @beta), university: @beta, outs: 18, losses: 1)
    BattingLine.create!(game: first, player: player(3, "井上 和輝", @alpha), university: @alpha, pa: 4, home_runs: 2)

    text = summary(first)

    assert_match "勝利投手は渡辺 和大（#{@alpha.short_name}）、敗戦投手は南 陽人（#{@beta.short_name}）。", text
    assert_match "本塁打は井上 和輝（#{@alpha.short_name}）2本。", text
  end

  test "tells an extra-inning walk-off win, as Scorebook marks it with an x" do
    innings = [ %w[0 0] ] * 11 + [ %w[1 2x] ]
    walk_off = game("2026-04-11", 1, 1, 2, innings: innings)

    assert_match "#{@beta.short_name}が延長12回の末、#{@alpha.short_name}に2-1でサヨナラ勝ちした。", summary(walk_off)
  end

  test "a home win in nine without an x is no walk-off" do
    win = game("2026-04-11", 1, 1, 2, innings: [ %w[0 0] ] * 8 + [ %w[1 x] ])

    assert_match "#{@beta.short_name}が#{@alpha.short_name}に2-1で勝った。", summary(win)
  end

  test "tells a draw, and a card with nothing but draws" do
    draw = game("2026-04-11", 1, 3, 3)

    assert_match "#{@alpha.short_name}と#{@beta.short_name}が3-3で引き分けた。", summary(draw)
    assert_match "これでこのカードは1引き分け。", summary(draw)
  end

  test "a playoff is told as one, with no card to count" do
    playoff = game("2026-06-01", 1, 6, 5, counted_in_stats: false)

    assert_match "2026年春季リーグ戦 優勝決定戦は、", summary(playoff)
    assert_no_match "カード", summary(playoff)
  end

  test "tells the weather in Tokyo when it is known" do
    first = game("2026-04-11", 1, 4, 2, weather_summary: "晴", temp_high: 21.5)

    assert_match "東京の天気は晴、最高気温21.5℃。", summary(first)
  end

  test "a game still to be played says when it will be" do
    scheduled = Game.create!(season: @season, team0: @alpha, team1: @beta, played_on: "2026-04-18", game_number: 1, game_status: "試合前")

    assert_equal "東京六大学野球 2026年春季リーグ戦 第1回戦、#{@alpha.short_name}対#{@beta.short_name}は2026年4月18日（土）に行われる予定。",
      GameSummary.new(scheduled, scoreboard: GameScoreboard.new(scheduled)).to_s
  end

  test "tells how the game moved the title race, winner first, and when it decided the title" do
    game("2026-04-11", 1, 4, 2)
    decider = game("2026-04-12", 2, 0, 5)
    clincher = game("2026-04-13", 3, 1, 2)

    assert_match "残りの試合の勝敗を五分とした優勝確率は、#{@beta.short_name}が25%から50%に上がり、#{@alpha.short_name}が75%から50%に下がった。", summary(decider)
    assert_match "これで#{@beta.short_name}の優勝が決まった。", summary(clincher)
  end

  test "tells the 勝ち点 won with the second win of a card, and how many the side has" do
    game("2026-04-11", 1, 4, 2)
    second = game("2026-04-12", 2, 3, 1)

    assert_match "これでこのカードは#{@alpha.short_name}の2勝0敗となり、#{@alpha.short_name}が勝ち点を得た（今季の勝ち点1）。", summary(second)
  end

  test "tells no 勝ち点 in a season not ranked by it" do
    @season = Season.create!(year: 2020, term: "autumn")
    game("2020-09-19", 1, 4, 2)
    second = game("2020-09-20", 2, 3, 1)

    assert_match "これでこのカードは#{@alpha.short_name}の2勝0敗。", summary(second)
    assert_no_match "勝ち点を得た", summary(second)
  end

  test "tells a season's only win and only loss, once the season is over" do
    first = game("2026-04-11", 1, 4, 2)
    game("2026-04-12", 2, 1, 3)
    last = game("2026-04-13", 3, 5, 0)

    assert_match "#{@alpha.short_name}にとってこのシーズン唯一の負け、#{@beta.short_name}にとってこのシーズン唯一の勝利となった。",
      summary(Game.find_by!(game_number: 2))
    assert_no_match "唯一", summary(first)
    assert_no_match "唯一", summary(last)

    pending_game_left
    assert_no_match "唯一", summary(Game.find_by!(game_number: 2))
  end

  test "tells how many seasons in a row the side has won when the game decides the title" do
    autumn = Season.create!(year: 2025, term: "autumn")
    Game.create!(season: autumn, team0: @alpha, team1: @beta, played_on: "2025-09-13", game_number: 1, team0_score: 2, team1_score: 0, game_status: "試合終了")
    Game.create!(season: autumn, team0: @beta, team1: @alpha, played_on: "2025-09-14", game_number: 2, team0_score: 0, team1_score: 1, game_status: "試合終了")
    game("2026-04-11", 1, 4, 2)
    clincher = game("2026-04-12", 2, 3, 1)

    assert_match "これで#{@alpha.short_name}の2シーズン連続の優勝が決まった。", summary(clincher)
  end
end
