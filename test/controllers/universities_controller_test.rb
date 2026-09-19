require "test_helper"

class UniversitiesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get universities_url
    assert_response :success
  end

test "show lists the current roster" do
  alpha = universities(:one)
  student = Player.create!(scorebook_id: 20236010, university: alpha, name: "落合 智哉", enter_year: 2023, role: "選手", position: "捕手", enrollment_status: 1)
  graduate = Player.create!(scorebook_id: 20101001, university: alpha, name: "卒業 太郎", enter_year: 2010, role: "選手", enrollment_status: 2)
  coach = Player.create!(scorebook_id: 19951099, university: alpha, name: "日野 愛郎", role: "監督", enrollment_status: 3)
  GameMember.create!(game: games(:one), player: coach, university: alpha, role: "監督", uniform_number: 30)

  get university_url(alpha.slug)

  assert_response :success
  assert_select "a[href=?]", player_path(student), text: "落合 智哉"
  assert_select "a[href=?]", player_path(coach), text: "日野 愛郎"
  assert_select "a[href=?]", player_path(graduate), false
  assert_match "2023年入学", response.body
end
end
