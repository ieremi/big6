require "test_helper"

class SyncRecentGamesJobTest < ActiveJob::TestCase
  setup do
    @alpha = universities(:one)
    @beta = universities(:two)
    @season = seasons(:one)
    Game.delete_all
  end

  def create_game(number, **attributes)
    Game.create!({ season: @season, team0: @alpha, team1: @beta, played_on: Date.current, game_number: number }.merge(attributes))
  end

  # Runs the job with every outside source stubbed, and returns what it asked for:
  # { synced: [season, ...], pages: [game, ...], stats: [game, ...] }. The schedule
  # stub gets the season.
  def run_job(schedule: ->(_season) { })
    calls = { synced: [], pages: [], stats: [] }

    stub_method(LeagueOfficialScheduleScraper, :call, schedule) do
      stub_method(SportsbullVideoScraper, :call, ->(_season) { }) do
        stub_method(JmaWeatherScraper, :call, ->(_year, _month) { }) do
          stub_method(ScorebookSync, :call, ->(season) { calls[:synced] << season }) do
            stub_method(LeagueOfficialGameScraper, :call, ->(game) { calls[:pages] << game }) do
              stub_method(GameStatsImport, :call, ->(games) { calls[:stats].concat(games) }) do
                SyncRecentGamesJob.perform_now
              end
            end
          end
        end
      end
    end

    calls
  end

  test "a scheduled game today is polled from Scorebook and the league's site" do
    game = create_game(1, game_status: "試合前")

    calls = run_job

    assert_equal [ @season ], calls[:synced]
    assert_equal [ game ], calls[:pages]
  end

  test "a cancelled game is not polled: there is no result to wait for" do
    create_game(1, game_status: "中止")

    calls = run_job

    assert_empty calls[:synced]
    assert_empty calls[:pages]
  end

  test "a game the schedule page has just marked cancelled is not polled either" do
    game = create_game(1, game_status: "試合前")
    other = create_game(2, game_status: "試合前")
    mark_cancelled = ->(_season) { game.reload.update!(game_status: "中止") } # as the schedule scraper does

    calls = run_job(schedule: mark_cancelled)

    assert_equal [ other ], calls[:pages]
    assert_equal [ @season ], calls[:synced] # the other game still needs Scorebook
  end

  # ---- a game under way isn't complete, though it has a score and innings

  def with_innings(game)
    game.season.update!(scorebook_games: [ { "id" => game.scorebook_game_id, "runs1Top" => "1", "runs1Bottom" => "0" } ])
    game.reload
  end

  test "a game under way with a score and innings is still polled" do
    game = with_innings(create_game(1, game_status: "in_progress", team0_score: 1, team1_score: 0, scorebook_game_id: 2026090101))

    calls = run_job

    assert_equal [ @season ], calls[:synced]
    assert_equal [ game ], calls[:pages]
  end

  test "a game that is over, with a score and innings, is not polled" do
    with_innings(create_game(1, game_status: "finished", team0_score: 1, team1_score: 0, scorebook_game_id: 2026090101))

    calls = run_job

    assert_empty calls[:synced]
    assert_empty calls[:pages]
  end

# ---- player box scores, which Scorebook can publish days after the game

def final_game(number, played_on)
  create_game(number, played_on: played_on, game_status: "finished", team0_score: 1, team1_score: 0, scorebook_game_id: 2026090100 + number)
end

test "a final game with no player lines is still fetched after the lookback window, even in a week with no games" do
  late = final_game(1, Date.current - 6)

  calls = run_job

  assert_equal [ late ], calls[:stats]
  assert_empty calls[:synced] # nothing recent to poll otherwise
end

test "a final game with player lines, or one too old, is not fetched again" do
  done = final_game(1, Date.current - 1)
  BattingLine.create!(game: done, player: Player.create!(scorebook_id: 20231001, university: @alpha, name: "田中 太郎", enter_year: 2023), university: @alpha)
  final_game(2, Date.current - SyncRecentGamesJob::STATS_LOOKBACK_DAYS - 1)

  assert_empty run_job[:stats]
end
end
