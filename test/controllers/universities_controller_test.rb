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
    assert_select "table[data-controller=sortable-table] td", text: "2023"
    assert_select "details.decade summary", text: "部員（1人）"
  end

  test "show puts the staff and the students in collapsible sections, closed by default" do
    alpha = universities(:one)
    Player.create!(scorebook_id: 20236010, university: alpha, name: "落合 智哉", enter_year: 2023, role: "選手", enrollment_status: 1)
    coach = Player.create!(scorebook_id: 19951099, university: alpha, name: "日野 愛郎", role: "監督", enrollment_status: 3)
    GameMember.create!(game: games(:one), player: coach, university: alpha, role: "監督", uniform_number: 30)

    get university_url(alpha.slug)

    assert_select "[data-controller=decade-fold] details.decade[data-decade-fold-target=decade]", 2
    assert_select "details.decade[open]", 0
    assert_select "details.decade summary", text: "監督・コーチ・部長（1人）"
    assert_select "button[data-action='decade-fold#openAll'][data-shortcut=u]", text: /すべて開く/
    assert_select "button[data-action='decade-fold#closeAll'][data-shortcut=f]", text: /すべて閉じる/
  end

  test "show gives the roster as a table sorted in the browser, with the players page's shortcuts" do
    alpha = universities(:one)
    Player.create!(scorebook_id: 20236010, university: alpha, name: "落合 智哉", name_kana: "オチアイ トモヤ", enter_year: 2023, role: "選手", position: "捕手", pitching_hand: "右", batting_hand: "左", high_school: "東邦", enrollment_status: 1)
    Player.create!(scorebook_id: 20221001, university: alpha, name: "山本 二郎", enter_year: 2022, role: "選手", position: "投手", enrollment_status: 1)

    get university_url(alpha.slug)

    assert_select "table[data-controller=sortable-table] th.sortable button", 6
    { "入学年" => "Y", "氏名" => "N", "役割" => "O", "位置" => "P", "投打" => "B", "出身高校" => "S" }.each do |label, shortcut|
      assert_select "th.sortable button[data-shortcut=?][data-shortcut-all]", shortcut, text: /\A#{label} /
    end
    # newest entry year first, as before, with sort values for the columns that need them
    assert_equal [ "落合 智哉", "山本 二郎" ], css_select("tbody td:nth-child(2) a").map(&:text)
    assert_select "td[data-sort-value=?]", "2023"
    assert_select "td[data-sort-value=?]", "オチアイ トモヤ" # the name sorts by its reading
    assert_select "td[data-sort-value=?]", "1", text: "捕手" # positions in fielding order: 投手 0, 捕手 1
    assert_select "td[data-sort-value=?]", "0", text: "投手"
  end
end
