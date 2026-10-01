require "test_helper"

class RosterDiffTest < ActiveSupport::TestCase
  setup do
    @alpha = universities(:one)
    @beta = universities(:two)
    @season = seasons(:two)
    Game.delete_all
    @players = {}
  end

  def player(name)
    @players[name] ||= Player.create!(scorebook_id: 1000 + @players.size, university: @alpha, name: name, enter_year: 2024, role: "選手", enrollment_status: 1)
  end

  def game(day, number, status: "試合終了", season: @season)
    Game.create!(season: season, team0: @alpha, team1: @beta, played_on: day, game_number: (number unless status == "中止"),
      team0_score: (1 unless status == "中止"), team1_score: (0 unless status == "中止"), game_status: status)
  end

  # members: { name => [batting order, position] }, nil for the bench.
  def roster(game, members)
    members.each do |name, (order, position)|
      GameMember.create!(game: game, player: player(name), university: @alpha, batting_order: order, fielding_position: position)
    end
  end

  def diff_for(game)
    RosterDiff.for_game(game, members_by_university: game.game_members.includes(:player).group_by(&:university_id))[@alpha.id]
  end

  def names(list)
    list.map { |item| (item.respond_to?(:player) ? item.player : item).name }
  end

  test "tells who came into and left the lineup, the moves in the order and the field, and the bench's changes" do
    before = game("2026-09-12", 1)
    roster(before, "一番" => [ 1, "中" ], "二番" => [ 2, "二" ], "三番" => [ 3, "三" ], "先発" => [ nil, "投" ], "控え" => nil, "去る" => nil)
    now = game("2026-09-13", 2)
    roster(now, "一番" => [ 2, "中" ], "二番" => [ 1, "遊" ], "控え" => [ 3, "三" ], "次の先発" => [ nil, "投" ], "三番" => nil, "来た" => nil)

    diff = diff_for(now)

    assert_equal before, diff.previous_game
    assert_equal %w[控え 次の先発], names(diff.new_starters)
    assert_equal %w[三番 先発], names(diff.dropped_starters)
    assert_equal [ [ "一番", 1, 2 ], [ "二番", 2, 1 ] ], diff.order_changes.map { |move| [ move.player.name, move.from_order, move.to_order ] }
    assert_equal [ [ "二番", "二", "遊" ] ], diff.position_changes.map { |move| [ move.player.name, move.from_position, move.to_position ] }
    assert_equal %w[来た], names(diff.joined) # 次の先発 joined too, but is told among the starters
    assert_equal %w[去る], names(diff.left)    # and 先発 left
    assert diff.from_outside?(player("次の先発"))
    assert_not diff.from_outside?(player("控え"))
    assert diff.now_outside?(player("先発"))
    assert_not diff.now_outside?(player("三番"))
  end

  test "the same members in the same places are no change" do
    roster(game("2026-09-12", 1), "一番" => [ 1, "中" ], "控え" => nil)
    now = game("2026-09-13", 2)
    roster(now, "一番" => [ 1, "中" ], "控え" => nil)

    assert_not diff_for(now).any?
  end

  test "the previous game is the latest earlier one of the season with members, skipping those without and those not held" do
    roster(game("2026-04-12", 1, season: seasons(:one)), "春" => [ 1, "中" ])
    with_members = game("2026-09-12", 1)
    roster(with_members, "一番" => [ 1, "中" ])
    game("2026-09-13", 2) # no members yet
    game("2026-09-14", nil, status: "中止")
    now = game("2026-09-15", 3)
    roster(now, "一番" => [ 1, "中" ])

    assert_equal with_members, diff_for(now).previous_game
  end

  test "a season's first game has no previous game" do
    roster(game("2026-04-12", 1, season: seasons(:one)), "春" => [ 1, "中" ])
    now = game("2026-09-12", 1)
    roster(now, "一番" => [ 1, "中" ])

    assert_nil diff_for(now)
  end

  test "against a provisional lineup only the starters are compared, the pitcher who relieved not counting as one" do
    before = game("2026-09-12", 1)
    roster(before, "一番" => [ 1, "中" ], "先発" => [ nil, "投" ], "控え" => nil)
    now = game("2026-09-13", 2, status: "試合中")
    now.update!(league_official_data: { "lineup" => [
      { "side" => "top", "name" => "一番", "order" => 1, "position" => "中" },
      { "side" => "top", "name" => "次の先発", "order" => nil, "position" => "投" },
      { "side" => "top", "name" => "代打", "order" => nil, "position" => "左" },
      { "side" => "top", "name" => "救援", "order" => nil, "position" => nil }
    ] })
    %w[次の先発 代打 救援].each { |name| player(name) }

    diff = RosterDiff.for_game(now, members_by_university: {}, official_lineup: LeagueOfficialLineup.new(now))[@alpha.id]

    assert_not diff.compare_bench?
    assert_equal %w[次の先発], names(diff.new_starters)
    assert_equal %w[先発], names(diff.dropped_starters)
    assert_empty diff.joined
    assert_empty diff.left
  end
end
