require "test_helper"

class JinguBig6RecordTest < ActiveSupport::TestCase
  setup do
    Game.delete_all
    @alpha, @beta = universities(:one), universities(:two)
  end

  teardown do
    File.delete(@path) if @path && File.exist?(@path)
  end

  # A data file of these years (as db/articles/jingu_big6.yml has them).
  def record(years)
    @path = Rails.root.join("tmp/jingu_big6_test_#{Process.pid}.yml")
    File.write(@path, { "sources" => {}, "cancelled" => [ 1988 ], "years" => years }.to_yaml)
    JinguBig6Record.new(path: @path)
  end

  # An autumn season the given university won 2-0 against the other.
  def autumn(year, winner)
    season = Season.find_or_create_by!(year: year, term: "autumn")
    loser = winner == @alpha ? @beta : @alpha
    2.times do |n|
      Game.create!(season:, team0: winner, team1: loser, played_on: Date.new(year, 10, 1) + n, game_number: n + 1,
        team0_score: 3, team1_score: 1, game_status: "試合終了")
    end
  end

  test "each university's entries and how far they went, the most titles first" do
    autumn(2001, @alpha)
    autumn(2002, @beta)
    autumn(2003, @beta)
    jingu = record([
      { "year" => 2001, "entrants" => [ { "university" => "alpha", "result" => "early" } ] },
      { "year" => 2002, "entrants" => [ { "university" => "beta", "result" => "champion" } ] },
      { "year" => 2003, "entrants" => [ { "university" => "beta", "result" => "runner_up" } ] }
    ])

    tallies = jingu.by_university.map { |tally| [ tally.university, tally.entries, tally.results["champion"], tally.results["runner_up"] ] }

    assert_equal [ [ @beta, 2, 1, 1 ], [ @alpha, 1, 0, 0 ] ], tallies
    assert_equal({ "champion" => 1, "runner_up" => 1, "semifinal" => 0, "early" => 1 }, jingu.results)
    assert_equal({ 2000 => [ 3, { "champion" => 1, "runner_up" => 1, "semifinal" => 0, "early" => 1 } ] }, jingu.by_decade)
    assert_equal 32, jingu.years.first.edition # 1970 was the first
  end

  test "the years the autumn champion didn't go, with the entrant's place, and the games won and lost" do
    autumn(2005, @alpha)
    jingu = record([
      { "year" => 2005, "entrants" => [ { "university" => "beta", "result" => "semifinal" } ],
        "games" => [ { "round" => "2回戦", "opponent" => "某大", "runs" => 3, "allowed" => 1 }, { "round" => "準決勝", "opponent" => "他大", "runs" => 0, "allowed" => 2 } ] }
    ])

    year, entrant, place = jingu.without_champion.first

    assert_equal [ 2005, @alpha, @beta, 2 ], [ year.year, year.autumn_champion, entrant.university, place ]
    assert_equal [ 1, 1 ], jingu.games_record
  end

  test "the data file has every tournament held from 1970, each with an entrant of a known result" do
    data = YAML.load_file(Rails.root.join("db/articles/jingu_big6.yml"))

    held = (1970..data["years"].last["year"]).to_a - data["cancelled"]
    assert_equal held, data["years"].map { |year| year["year"] }
    assert data["years"].all? { |year| year["entrants"].any? && year["entrants"].all? { |entrant| JinguBig6Record::RESULTS.key?(entrant["result"]) } }
    assert_equal 16, data["years"].sum { |year| year["entrants"].count { |entrant| entrant["result"] == "champion" } } # to 2026
  end
end
