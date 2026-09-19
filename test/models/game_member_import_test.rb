require "test_helper"

class GameMemberImportTest < ActiveSupport::TestCase
  setup do
    @keio = University.create!(name: "慶應義塾大学", short_name: "慶大", slug: "keio", position: 3)
    @rikkio = University.create!(name: "立教大学", short_name: "立大", slug: "rikkio", position: 4)
    @season = Season.create!(year: 2026, term: "spring")
    @game = Game.create!(season: @season, team0: @keio, team1: @rikkio, played_on: "2026-05-24", game_number: 1, scorebook_game_id: 2026052401)
    @imai = Player.create!(scorebook_id: 20231001, university: @keio, name: "今津 慶介", enter_year: 2023)
    @ochiai = Player.create!(scorebook_id: 20236010, university: @rikkio, name: "落合 智哉", enter_year: 2023)
  end

  def game_info(id, members)
    { "id" => id, "GameMember" => members }
  end

  def member(member_id, team_id, overrides = {})
    { "memberId" => member_id, "teamId" => team_id, "number" => 10, "grade" => 3, "startingBatter" => 2,
      "startingTeamRole" => "捕手", "startingPositionJp" => "捕" }.merge(overrides)
  end

  def import(*games)
    @season.update!(scorebook_games: games)
    GameMemberImport.call
  end

  test "links roster entries to games and players" do
    result = import(game_info(2026052401, [ member(20231001, 2, "number" => 2), member(20236010, 6) ]))

    assert_equal({ games: 1, members: 2, skipped: 0 }, result)
    entry = GameMember.find_by!(game: @game, player: @ochiai)
    assert_equal [ @rikkio, 10, 3, "捕手", 2, "捕" ], [ entry.university, entry.uniform_number, entry.grade, entry.role, entry.batting_order, entry.fielding_position ]
    assert_equal 2, GameMember.find_by!(game: @game, player: @imai).uniform_number
  end

  test "counts people who were not imported as skipped" do
    result = import(game_info(2026052401, [ member(20236010, 6), member(99999999, 6) ]))

    assert_equal({ games: 1, members: 1, skipped: 1 }, result)
  end

  test "re-running replaces a game's entries rather than adding to them" do
    import(game_info(2026052401, [ member(20231001, 2), member(20236010, 6) ]))
    import(game_info(2026052401, [ member(20236010, 6, "number" => 27) ]))

    assert_equal [ @ochiai.id ], @game.game_members.pluck(:player_id)
    assert_equal 27, @game.game_members.first.uniform_number
  end

  test "a game without a roster list keeps its existing entries" do
    import(game_info(2026052401, [ member(20236010, 6) ]))
    result = import(game_info(2026052401, nil))

    assert_equal({ games: 0, members: 0, skipped: 0 }, result)
    assert_equal 1, @game.game_members.count
  end

  test "ignores scorebook games that are not in the database" do
    result = import(game_info(1900010101, [ member(20236010, 6) ]))

    assert_equal({ games: 0, members: 0, skipped: 0 }, result)
    assert_equal 0, GameMember.count
  end

  test "a person listed twice for the same game is stored once" do
    import(game_info(2026052401, [ member(20236010, 6), member(20236010, 6, "number" => 99) ]))

    assert_equal 1, @game.game_members.count
  end
end
