require "test_helper"

class LeagueOfficialScheduleScraperTest < ActiveSupport::TestCase
  setup do
    @hosei = University.create!(name: "Hosei University", short_name: "法大", slug: "hosei", position: 4)
    @rikkio = University.create!(name: "Rikkio University", short_name: "立大", slug: "rikkio", position: 6)
    @season = Season.create!(year: 2026, term: "autumn")
  end

  # The league's schedule page, cut down to what the scraper reads: a row per day,
  # with each game's teams and, in the last column, a result link or "中止".
  def schedule(*days)
    rows = days.map do |date, *games|
      cells = games.map do |left, middle, right, cancelled|
        result = cancelled ? %(<span class="text10px">中止</span>) : %(<a href="game.php">結果</a>)
        %(<div class="content_left"><table><tr><td class="scd_vs">#{left}</td><td class="scd_vs">#{middle}</td><td class="scd_vs">#{right}</td><td class="text13px">#{result}</td></tr></table></div>)
      end
      %(<tr><td class="scd_date">#{date} (日)</td><td class="text14px"></td><td class="text13px">11:00</td><td>#{cells.join}</td></tr>)
    end
    Nokogiri::HTML("<html><body><table>#{rows.join}</table></body></html>")
  end

  def scrape(doc)
    scraper = LeagueOfficialScheduleScraper.new(@season)
    stub_method(scraper, :fetch_doc, ->(*) { doc }) { scraper.call }
  end

  def create_game(day, number, **attributes)
    Game.create!({ season: @season, team0: @hosei, team1: @rikkio, played_on: day, game_number: number }.merge(attributes))
  end

  test "a game the schedule shows as 中止 is marked cancelled on the game we have" do
    played = create_game("2026-09-19", 1, game_status: "試合終了", team0_score: 5, team1_score: 12)
    cancelled = create_game("2026-09-20", 2, game_status: "試合前")

    scrape(schedule([ "9/19", [ "法大", "5 - 12", "立大" ] ], [ "9/20", [ "法大", "-", "立大", true ] ]))

    assert_equal "中止", cancelled.reload.game_status
    assert_equal [ "試合終了", 5 ], [ played.reload.game_status, played.team0_score ]
  end

  test "a cancelled game we do not have is not created, and returns nothing" do
    created = scrape(schedule([ "9/21", [ "法大", "-", "立大", true ] ]))

    assert_empty created
    assert_equal 0, Game.where(season: @season).count
  end

  test "the replay of a cancelled game is created with the number the cancelled one had, not the next" do
    create_game("2026-09-19", 1, game_status: "試合終了", team0_score: 5, team1_score: 12)
    create_game("2026-09-20", 2, game_status: "試合前")

    created = scrape(schedule(
      [ "9/19", [ "法大", "5 - 12", "立大" ] ],
      [ "9/20", [ "法大", "-", "立大", true ] ],
      [ "9/21", [ "法大", "-", "立大", true ] ],
      [ "9/22", [ "法大", "-", "立大" ] ]
    ))

    assert_equal [ [ "2026-09-22", 2 ] ], created.map { |game| [ game.played_on.to_s, game.game_number ] }
    assert_equal [ [ "2026-09-19", 1, nil ], [ "2026-09-20", 2, "中止" ], [ "2026-09-22", 2, nil ] ],
      Game.where(season: @season).order(:played_on).map { |game| [ game.played_on.to_s, game.game_number, game.game_status.presence.then { |s| s == "試合終了" ? nil : s } ] }
  end

  test "games with no 中止 are created as before" do
    created = scrape(schedule([ "9/26", [ "法大", "-", "立大" ] ]))

    assert_equal [ [ "2026-09-26", 1 ] ], created.map { |game| [ game.played_on.to_s, game.game_number ] }
  end

  test "a game already cancelled stays so when the schedule is read again" do
    cancelled = create_game("2026-09-20", 2, game_status: "中止")

    2.times { scrape(schedule([ "9/20", [ "法大", "-", "立大", true ] ])) }

    assert_equal "中止", cancelled.reload.game_status
    assert_equal 1, Game.where(season: @season).count
  end
end
