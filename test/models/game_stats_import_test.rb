require "test_helper"

class GameStatsImportTest < ActiveSupport::TestCase
  # Feeds GameStatsImport canned game pages instead of calling Scorebook. A
  # value of nil stands for a page that couldn't be fetched.
  class FakeImport < GameStatsImport
    def initialize(games, pages)
      super(games, sleep_seconds: 0)
      @pages = pages
    end

    private

    def fetch_game_stats(game)
      @pages.fetch(game.scorebook_game_id)
    end
  end

  setup do
    @keio = University.create!(name: "慶應義塾大学", short_name: "慶大", slug: "keio", position: 3)
    @rikkio = University.create!(name: "立教大学", short_name: "立大", slug: "rikkio", position: 4)
    @game = Game.create!(season: seasons(:one), team0: @keio, team1: @rikkio, played_on: "2026-05-24", game_number: 1,
      team0_score: 3, team1_score: 2, scorebook_game_id: 2026052401)
    @imazu = Player.create!(scorebook_id: 20231007, university: @keio, name: "今津 慶介", enter_year: 2023)
    @ochiai = Player.create!(scorebook_id: 20236010, university: @rikkio, name: "落合 智哉", enter_year: 2023)
  end

  def batter(member_id, team_id, overrides = {})
    { "memberId" => member_id, "teamId" => team_id, "position" => "[捕]", "pa" => 4, "ab" => 3, "rb" => 1, "hb" => 2, "twob" => 1, "threeb" => 0,
      "hrb" => 0, "tb" => 3, "rbi" => 2, "sob" => 1, "bbTotal" => 1, "sac" => 0, "sb" => 1, "cs" => 0, "gidp" => 0, "error" => 0 }.merge(overrides)
  end

  def pitcher(member_id, team_id, overrides = {})
    { "memberId" => member_id, "teamId" => team_id, "bf" => 13, "ip" => "3", "ip03" => 1, "hp" => 4, "hrp" => 0, "bbTotalp" => 1, "sop" => 2,
      "rp" => 3, "er" => 3, "np" => 58, "gs" => 1, "cg" => 0, "sho" => 0, "win" => 0, "lose" => 1 }.merge(overrides)
  end

  def import(stats, game: @game)
    FakeImport.new([ game ], { game.scorebook_game_id => stats }).call
  end

  test "imports batting and pitching lines and marks the game as checked" do
    result = import({ "batterTop" => [ batter(20231007, 2) ], "batterBottom" => [ batter(20236010, 6, "hb" => 0, "hrb" => 1) ],
                      "pitcherTop" => [ pitcher(20231007, 2) ], "pitcherBottom" => [] })

    assert_equal({ games: 1, batting_lines: 2, pitching_lines: 1, skipped: 0, without_stats: 0, failed: 0 }, result)
    line = BattingLine.find_by!(game: @game, player: @imazu)
    assert_equal [ @keio, "[捕]", 4, 3, 1, 2, 1, 0, 0, 3, 2, 1, 1, 0, 1, 0, 0 ],
      [ line.university, line.position, line.pa, line.ab, line.runs, line.hits, line.doubles, line.triples, line.home_runs, line.total_bases,
        line.rbi, line.strikeouts, line.walks, line.sacrifices, line.stolen_bases, line.caught_stealing, line.fielding_errors ]
    assert_equal 1, BattingLine.find_by!(game: @game, player: @ochiai).home_runs
    assert_not_nil @game.reload.stats_checked_at
  end

  test "stores innings pitched as outs" do
    import({ "pitcherTop" => [ pitcher(20231007, 2, "ip" => "3", "ip03" => 1) ], "pitcherBottom" => [ pitcher(20236010, 6, "ip" => "9", "ip03" => 0, "cg" => 1) ] })

    assert_equal 10, PitchingLine.find_by!(player: @imazu).outs
    assert_equal [ 27, 1 ], PitchingLine.find_by!(player: @ochiai).values_at(:outs, :complete_game)
  end

  test "works total bases out from the hits, since Scorebook's tb is often 0" do
    # a double, a triple, and a home run: 2 + 3 + 4 bases
    import({ "batterTop" => [ batter(20231007, 2, "hb" => 3, "twob" => 1, "threeb" => 1, "hrb" => 1, "tb" => 0) ] })

    assert_equal 2 + 3 + 4, BattingLine.find_by!(player: @imazu).total_bases
  end

  test "total bases ignore Scorebook's tb even when it is filled in" do
    import({ "batterTop" => [ batter(20231007, 2, "hb" => 2, "twob" => 1, "threeb" => 0, "hrb" => 0, "tb" => 99) ] })

    assert_equal 3, BattingLine.find_by!(player: @imazu).total_bases # a single and a double
  end

  test "reads innings pitched however Scorebook writes them" do
    [
      [ "9 2/3", 0, 29 ], # the fraction is in the text
      [ " 1/3", 0, 1 ],   # a third of an inning, padded
      [ "1 2/3", 0, 5 ],
      [ "2    ", 1, 7 ],  # whole innings padded with spaces, the third in ip03
      [ "2    ", 2, 8 ],
      [ "0", 0, 0 ],
      [ "", 1, 1 ]
    ].each do |ip, ip03, expected|
      PitchingLine.delete_all
      import({ "pitcherTop" => [ pitcher(20231007, 2, "ip" => ip, "ip03" => ip03) ] })

      assert_equal expected, PitchingLine.find_by!(player: @imazu).outs, "ip=#{ip.inspect} ip03=#{ip03}"
    end
  end

  test "skips people who were not imported as players" do
    result = import({ "batterTop" => [ batter(20231007, 2), batter(99999999, 2) ], "pitcherTop" => [ pitcher(88888888, 2) ] })

    assert_equal 2, result[:skipped]
    assert_equal 1, BattingLine.count
    assert_equal 0, PitchingLine.count
  end

  test "skips rows for teams that are not in the league" do
    result = import({ "batterTop" => [ batter(20231007, 99) ] })

    assert_equal 1, result[:skipped]
    assert_equal 0, BattingLine.count
  end

  test "re-importing replaces a game's lines instead of adding to them" do
    import({ "batterTop" => [ batter(20231007, 2), batter(20236010, 6) ] })
    import({ "batterTop" => [ batter(20231007, 2, "hb" => 3) ] })

    assert_equal [ @imazu.id ], @game.batting_lines.pluck(:player_id)
    assert_equal 3, @game.batting_lines.first.hits
  end

  test "re-importing keeps the lines an applied suggestion added, unless the page now has the player's own line" do
    suggestion = FixSuggestion.create!(kind: "misfiled_lines", key: "misfiled_lines 2026052402 6", confidence: "likely", status: "approved",
      university: @rikkio, game: @game)
    BattingLine.create!(game: @game, player: @ochiai, university: @rikkio, fix_suggestion: suggestion, pa: 5, ab: 5, hits: 4)

    import({ "batterTop" => [ batter(20231007, 2) ], "pitcherTop" => [ pitcher(20231007, 2) ] })

    assert_equal [ @imazu.id, @ochiai.id ].sort, @game.batting_lines.pluck(:player_id).sort
    assert_equal suggestion, @game.batting_lines.find_by(player: @ochiai).fix_suggestion

    import({ "batterTop" => [ batter(20231007, 2), batter(20236010, 6, "hb" => 3) ] })

    ochiai = @game.batting_lines.find_by(player: @ochiai)
    assert_nil ochiai.fix_suggestion
    assert_equal 3, ochiai.hits
  end

  test "a player listed twice for a game is stored once" do
    import({ "batterTop" => [ batter(20231007, 2), batter(20231007, 2, "hb" => 9) ] })

    assert_equal 1, @game.batting_lines.count
  end

  test "a page with no player stats keeps existing lines but is still marked checked" do
    import({ "batterTop" => [ batter(20231007, 2) ] })
    @game.update_column(:stats_checked_at, nil)

    result = import({})

    assert_equal 1, result[:without_stats]
    assert_equal 1, @game.batting_lines.count
    assert_not_nil @game.reload.stats_checked_at
  end

  test "a page that could not be fetched keeps existing lines and is not marked checked" do
    import({ "batterTop" => [ batter(20231007, 2) ] })
    @game.update_column(:stats_checked_at, nil)

    result = import(nil)

    assert_equal 1, result[:failed]
    assert_equal 1, @game.batting_lines.count
    assert_nil @game.reload.stats_checked_at
  end

  def page(next_data_tag)
    "<html><head><title>t</title></head><body><div>ignored</div>#{next_data_tag}<script>other()</script></body></html>"
  end

  test "game_stats_from cuts the gameStats out of the embedded page data" do
    html = page(%(<script id="__NEXT_DATA__" type="application/json">{"props":{"pageProps":{"gameInfo":{"id":1},"gameStats":{"batterTop":[{"memberId":7}]}}}}</script>))

    assert_equal({ "batterTop" => [ { "memberId" => 7 } ] }, GameStatsImport.game_stats_from(html))
  end

  test "game_stats_from does not depend on the attribute order or spacing of the script tag" do
    html = page(%(<script type="application/json"  id="__NEXT_DATA__">{"props":{"pageProps":{"gameStats":{"pitcherTop":[]}}}}</script>))

    assert_equal({ "pitcherTop" => [] }, GameStatsImport.game_stats_from(html))
  end

  test "game_stats_from returns an empty hash when the page has no player stats" do
    html = page(%(<script id="__NEXT_DATA__" type="application/json">{"props":{"pageProps":{"gameInfo":{}}}}</script>))

    assert_equal({}, GameStatsImport.game_stats_from(html))
  end

  test "game_stats_from returns nil when there is no embedded data or it is not JSON" do
    assert_nil GameStatsImport.game_stats_from("<html><body>no data here</body></html>")
    assert_nil GameStatsImport.game_stats_from(page(%(<script id="__NEXT_DATA__" type="application/json">{not json</script>)))
    assert_nil GameStatsImport.game_stats_from(page(%(<script id="__NEXT_DATA__" type="application/json">{"props":)))
  end

  test "game_stats_from reads Japanese text from a binary response body" do
    html = page(%(<script id="__NEXT_DATA__" type="application/json">{"props":{"pageProps":{"gameStats":{"batterTop":[{"nameIdentification":"落合"}]}}}}</script>)).b

    assert_equal "落合", GameStatsImport.game_stats_from(html).dig("batterTop", 0, "nameIdentification")
  end
end
