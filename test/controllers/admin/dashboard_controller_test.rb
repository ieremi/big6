require "test_helper"

class Admin::DashboardControllerTest < ActionDispatch::IntegrationTest
  test "the dashboard shows how far the Scorebook check and the review of the games data check have got" do
    player = Player.create!(scorebook_id: 70_000_001, university: universities(:one), name: "選手", enter_year: 2023)
    BattingLine.create!(game: games(:one), player: player, university: player.university, pa: 4)
    sign_in

    get admin_path

    assert_response :success
    assert_select ".admin-progress progress[value='0'][max='1']"
    assert_select ".admin-progress strong", text: "0 / 1人"
    assert_select ".admin-progress p.muted", text: /残り1人、あと約1晩（1晩に480人）/
    assert_select ".admin-progress strong", text: /\A0 \/ \d+件\z/
    assert_select ".admin-progress-table a[href*='kind=same_day']", text: GameDataCheck::KINDS["same_day"]
  end
end
