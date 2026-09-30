require "test_helper"

class LeagueOfficialLineupTest < ActiveSupport::TestCase
  setup do
    @alpha = universities(:one)
    @game = games(:one)
  end

  def add_player(scorebook_id, name, high_school, **attributes)
    Player.create!({ scorebook_id: scorebook_id, university: @alpha, name: name, high_school: high_school,
      enter_year: 2023, role: "選手", enrollment_status: Player::ACTIVE_ENROLLMENT_STATUS }.merge(attributes))
  end

  def lineup_of(*entries)
    @game.update!(league_official_data: { "lineup" => entries.map { |entry| { "side" => "top", "grade" => 4 }.merge(entry) } })
    LeagueOfficialLineup.new(@game).by_university.fetch(@alpha.id, []).map { |entry| entry.player.name }
  end

  test "matches a player by the short form of the name and the high school" do
    add_player(1, "吉野 太陽", "慶應")

    assert_equal [ "吉野 太陽" ], lineup_of({ "name" => "吉野", "high_school" => "慶應", "order" => 7 })
  end

  test "matches a high school the box score cut short" do
    add_player(1, "上田 太陽", "國學院久我山")

    assert_equal [ "上田 太陽" ], lineup_of({ "name" => "上田", "high_school" => "國學院久我", "order" => 9 })
  end

  test "leaves out a player of another high school, or one it can't tell apart" do
    add_player(1, "上田 太陽", "國學院久我山")
    add_player(2, "林 純司", "報徳学園", enter_year: 2024)
    add_player(3, "林 純平", "報徳学園", enter_year: 2024)

    assert_empty lineup_of({ "name" => "上田", "high_school" => "慶應" }, { "name" => "林純", "high_school" => "報徳学園", "grade" => nil })
  end
end
