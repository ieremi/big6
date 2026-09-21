require "test_helper"

class RefreshLiveScoreboardsJobTest < ActiveJob::TestCase
  setup do
    @alpha = universities(:one)
    @beta = universities(:two)
    @spring = seasons(:one)
    @autumn = seasons(:two)
    Game.delete_all
  end

  def create_game(number, status: "in_progress", season: @spring, played_on: Date.current, **attributes)
    Game.create!({ season: season, team0: @alpha, team1: @beta, played_on: played_on, game_number: number, game_status: status }.merge(attributes))
  end

  # Runs the job with Scorebook and the league's site stubbed, and returns what it
  # asked for. sync and official are called with the season (and the members option)
  # and with the game; they can change the database, or raise.
  def run_job(sync: ->(_season, **_options) { }, official: ->(_game) { })
    calls = { synced: [], pages: [] }

    stub_method(ScorebookSync, :call, ->(season, **options) { calls[:synced] << [ season, options ]; sync.call(season, **options) }) do
      stub_method(LeagueOfficialGameScraper, :call, ->(game) { calls[:pages] << game; official.call(game) }) do
        RefreshLiveScoreboardsJob.perform_now
      end
    end

    calls
  end

  test "a game under way has its season's Scorebook data refreshed, without the bench members" do
    game = create_game(1)

    calls = run_job

    assert_equal [ [ @spring, { members: false } ] ], calls[:synced]
    assert_equal [ game ], calls[:pages]
  end

  test "it asks for nothing when no game is under way" do
    create_game(1, status: "scheduled")
    create_game(2, status: "finished", team0_score: 3, team1_score: 1)
    create_game(3, status: "cancelled", game_number: nil)

    calls = run_job

    assert_empty calls[:synced]
    assert_empty calls[:pages]
  end

  test "several games under way in one season are one refresh of it, and each gets its provisional score" do
    first = create_game(1)
    second = create_game(2, played_on: Date.current - 1)
    other = create_game(1, season: @autumn)

    calls = run_job

    assert_equal [ @spring, @autumn ].sort_by(&:id), calls[:synced].map(&:first).sort_by(&:id)
    assert_equal [ first, second, other ].sort_by(&:id), calls[:pages].sort_by(&:id)
  end

  test "a game marked 試合中 days ago is stale data, not one to poll every five minutes" do
    create_game(1, played_on: Date.current - 2)

    calls = run_job

    assert_empty calls[:synced]
  end

  test "a game that Scorebook now has as over gets no provisional score from the league's site" do
    game = create_game(1)
    over = ->(_season, **_options) { game.reload.update!(game_status: "finished", team0_score: 4, team1_score: 2) }

    calls = run_job(sync: over)

    assert_equal 1, calls[:synced].size
    assert_empty calls[:pages]
  end

  test "Scorebook failing does not stop the league's site being asked, or fail the job" do
    game = create_game(1)

    calls = run_job(sync: ->(_season, **_options) { raise SocketError, "no route" })

    assert_equal [ game ], calls[:pages]
  end

  test "the league's site failing does not fail the job" do
    create_game(1)

    assert_nothing_raised { run_job(official: ->(_game) { raise Timeout::Error, "slow" }) }
  end

  # ---- a game still marked 試合前 whose scheduled start has passed

  # A moment in Tokyo on 2026-05-02 (the app's own zone is UTC).
  def at_tokyo(hour, minute = 0, &block)
    travel_to(ActiveSupport::TimeZone["Asia/Tokyo"].local(2026, 5, 2, hour, minute), &block)
  end

  def scheduled_game(number, starting_at, **attributes)
    create_game(number, status: "scheduled", played_on: Date.new(2026, 5, 2), league_official_data: { "scheduledStartTime" => starting_at }, **attributes)
  end

  test "a game marked 試合前 is asked about once its scheduled start has passed" do
    game = scheduled_game(1, "11:00")

    at_tokyo(11, 5) do
      calls = run_job

      assert_equal [ @spring ], calls[:synced].map(&:first)
      assert_equal [ game ], calls[:pages]
    end
  end

  test "and not before it" do
    scheduled_game(1, "11:00")

    at_tokyo(10, 55) do
      assert_empty run_job[:synced]
    end
  end

  test "and not for ever: only for the three hours after it" do
    scheduled_game(1, "11:00")

    at_tokyo(13, 55) { assert_equal 1, run_job[:synced].size }
    at_tokyo(14, 0) { assert_empty run_job[:synced] }
  end

  test "the second game of the day has its window three hours later" do
    first = scheduled_game(1, "11:00", game_order: 1)
    second = scheduled_game(2, "14:00", game_order: 2)

    at_tokyo(12, 0) { assert_equal [ first ], run_job[:pages] }
    at_tokyo(14, 30) { assert_equal [ second ], run_job[:pages] }
  end

  test "a game marked 試合前 with no known start is not asked about" do
    create_game(1, status: "scheduled", played_on: Date.new(2026, 5, 2))

    at_tokyo(12, 0) { assert_empty run_job[:synced] }
  end

  test "a game marked 試合前 that is not today's is not asked about" do
    create_game(1, status: "scheduled", played_on: Date.new(2026, 5, 1), league_official_data: { "scheduledStartTime" => "11:00" })
    create_game(2, status: "scheduled", played_on: Date.new(2026, 5, 3), league_official_data: { "scheduledStartTime" => "11:00" })

    at_tokyo(12, 0) { assert_empty run_job[:synced] }
  end

  test "the day is Tokyo's, not the app's UTC one" do
    game = scheduled_game(1, "01:00") # ten past midnight in Tokyo is still the 1st in UTC

    at_tokyo(1, 10) do
      assert_equal [ game ], run_job[:pages]
    end
  end

  test "a game marked 試合前 that is over or called off by then is not asked about again" do
    game = scheduled_game(1, "11:00")
    settled = ->(_season, **_options) { game.reload.update!(game_status: "cancelled") }

    at_tokyo(11, 10) do
      calls = run_job(sync: settled)

      assert_equal 1, calls[:synced].size
      assert_empty calls[:pages]
    end
  end

  test "a game under way and one about to be are one refresh of the season, and both are asked for" do
    under_way = create_game(1, played_on: Date.new(2026, 5, 2))
    due = scheduled_game(2, "11:00")

    at_tokyo(11, 30) do
      calls = run_job

      assert_equal [ @spring ], calls[:synced].map(&:first)
      assert_equal [ under_way, due ].sort_by(&:id), calls[:pages].sort_by(&:id)
    end
  end

  test "the job is run every five minutes, and one at a time" do
    schedule = YAML.load_file(Rails.root.join("config/recurring.yml")).fetch("production").fetch("refresh_live_scoreboards")

    assert_equal [ "RefreshLiveScoreboardsJob", "every 5 minutes" ], schedule.values_at("class", "schedule")
    assert_equal 1, RefreshLiveScoreboardsJob.concurrency_limit
    assert_equal :discard, RefreshLiveScoreboardsJob.concurrency_on_conflict
  end
end
