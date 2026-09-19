require "test_helper"

class UniversityRosterTest < ActiveSupport::TestCase
  setup do
    @alpha = universities(:one)
    @beta = universities(:two)
    @roster = UniversityRoster.new(@alpha)
  end

  def create_player(scorebook_id, name, **attributes)
    Player.create!({ scorebook_id: scorebook_id, university: @alpha, name: name, enter_year: 2024, role: "選手", enrollment_status: 1 }.merge(attributes))
  end

  test "students are grouped by entry year, newest first, and only include current students" do
    create_player(1, "二年", enter_year: 2025)
    create_player(2, "三年", enter_year: 2024)
    create_player(3, "三年マネージャー", enter_year: 2024, role: "マネージャー")
    create_player(4, "卒業生", enter_year: 2020, enrollment_status: 2)
    create_player(5, "退部", enter_year: 2024, enrollment_status: 3)
    create_player(6, "監督", enter_year: nil, role: "監督")
    Player.create!(scorebook_id: 7, university: @beta, name: "他大学", enter_year: 2024, role: "選手", enrollment_status: 1)

    assert_equal [ 2025, 2024 ], @roster.students_by_entry_year.keys
    assert_equal %w[三年 三年マネージャー], @roster.students_by_entry_year[2024].map(&:name)
    assert_equal 3, @roster.student_count
  end

  test "staff come from the latest game that has a roster, most senior first" do
    old_game = games(:one)
    new_game = Game.create!(season: seasons(:one), team0: @alpha, team1: @beta, played_on: "2026-08-20", game_number: 2)
    old_coach = create_player(10, "前の監督", enter_year: nil, role: "監督")
    manager = create_player(11, "新監督", enter_year: nil, role: "監督")
    director = create_player(12, "部長", enter_year: nil, role: "部長")
    student = create_player(13, "学生", enter_year: 2024)

    GameMember.create!(game: old_game, player: old_coach, university: @alpha, role: "監督")
    [ manager, student, director ].each { |p| GameMember.create!(game: new_game, player: p, university: @alpha, role: p.role) }

    assert_equal %w[部長 新監督], @roster.staff.map { |m| m.player.name }
  end

  test "staff is empty when no game has a roster" do
    assert_empty @roster.staff
  end
end
