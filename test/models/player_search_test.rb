require "test_helper"

class PlayerSearchTest < ActiveSupport::TestCase
  setup do
    @alpha = universities(:one)
    @beta = universities(:two)
    @ochiai = Player.create!(scorebook_id: 20236010, university: @alpha, name: "落合 智哉", name_kana: "オチアイ トモヤ", enter_year: 2023, role: "選手", enrollment_status: 1, high_school: "東邦")
    @imazu = Player.create!(scorebook_id: 20231007, university: @beta, name: "今津 慶介", enter_year: 2023, role: "マネージャー", enrollment_status: 1)
    @old = Player.create!(scorebook_id: 19951001, university: @alpha, name: "山田 太郎", enter_year: 1995, role: "選手", enrollment_status: 2)
    @coach = Player.create!(scorebook_id: 19951099, university: @alpha, name: "日野 愛郎", enter_year: nil, role: "部長", enrollment_status: 3)
  end

  def found(**filters)
    PlayerSearch.new(**filters).ordered.map(&:scorebook_id)
  end

  test "no filters matches everyone, newest entry year first and those without one last" do
    assert_equal [ 20236010, 20231007, 19951001, 19951099 ], found
  end

  test "keyword matches the name with or without a space, the reading, and the high school" do
    assert_equal [ 20236010 ], found(keyword: "落合智哉")
    assert_equal [ 20236010 ], found(keyword: " 落合 智哉 ")
    assert_equal [ 20236010 ], found(keyword: "オチアイ")
    assert_equal [ 20236010 ], found(keyword: "東邦")
  end

  test "university_ids nil means any university and an empty list means none" do
    assert_equal 4, found(university_ids: nil).size
    assert_empty found(university_ids: [])
    assert_equal [ 20231007 ], found(university_ids: [ @beta.id ])
    assert_equal [ 20236010, 20231007 ], found(university_ids: [ @alpha.id, @beta.id ], start_year: 2023)
  end

  test "entry years may be given as strings and either end may be left open" do
    assert_equal [ 19951001 ], found(start_year: "1990", end_year: "2000")
    assert_equal [ 20236010, 20231007 ], found(start_year: "2000")
    assert_equal [ 19951001 ], found(end_year: "2000")
    assert_equal 4, found(start_year: "", end_year: "").size
  end

  test "role groups and enrollment status" do
    assert_equal [ 20236010, 19951001 ], found(role_group: "player")
    assert_equal [ 20231007 ], found(role_group: "manager")
    assert_equal [ 19951099 ], found(role_group: "staff")
    assert_equal [ 19951001 ], found(status: "alumni")
    assert_equal [ 20236010, 20231007 ], found(status: "active")
  end

  test "high school, faculty, role, and position match exactly" do
    @ochiai.update!(faculty: "商", position: "投手")
    @imazu.update!(high_school: "東邦", position: "捕手")

    assert_equal [ 20236010, 20231007 ], found(high_school: "東邦")
    assert_equal [ 20236010 ], found(faculty: "商")
    assert_equal [ 20236010, 19951001 ], found(role: "選手")
    assert_equal [ 20236010 ], found(position: "投手")
    assert_empty found(position: "遊撃手")
  end

  test "unknown role groups and statuses are ignored" do
    search = PlayerSearch.new(role_group: "bogus", status: "bogus")

    assert_nil search.role_group
    assert_nil search.status
    assert_equal 4, search.players.count
  end

  test "players is unordered and counts without the university join" do
    assert_equal 2, PlayerSearch.new(university_ids: [ @beta.id, @alpha.id ], start_year: 2023).players.count
  end

  # ---- ordered

  test "ordered puts the newest entry year first, then university and name, when given no sort" do
    assert_equal [ "落合 智哉", "今津 慶介", "山田 太郎", "日野 愛郎" ], PlayerSearch.new.ordered.map(&:name)
  end

  test "ordered by a column keeps the usual order among equal values, and unknown sorts are ignored" do
    assert_equal [ "山田 太郎", "落合 智哉", "今津 慶介", "日野 愛郎" ], PlayerSearch.new.ordered(sort: "enter_year", direction: "asc").map(&:name)
    assert_equal PlayerSearch.new.ordered.map(&:name), PlayerSearch.new.ordered(sort: "name; DROP TABLE players", direction: "desc").map(&:name)
  end

  test "ordered puts blanks last in either direction" do
    @ochiai.update!(position: "捕手")

    assert_equal "落合 智哉", PlayerSearch.new.ordered(sort: "position", direction: "asc").first.name
    assert_equal "落合 智哉", PlayerSearch.new.ordered(sort: "position", direction: "desc").first.name
  end

  test "the ranks that tables sorted in the browser use follow the same lists as the database order" do
    assert_equal [ 0, 1, 7, 8 ], [ "投手", "捕手", "外野手", "マネジャー" ].map { |position| PlayerSearch.position_rank(position) }
    assert_nil PlayerSearch.position_rank(nil)
    assert_equal [ 0, 1, 2, 3 ], [ "選手", "部長", "マネージャー", "特別要員" ].map { |role| PlayerSearch.role_rank(role) }
    assert_nil PlayerSearch.role_rank("")

    # pitching hand first, then batting hand; those with neither have none
    right_left = Player.new(pitching_hand: "右", batting_hand: "左")
    left_right = Player.new(pitching_hand: "左", batting_hand: "右")
    assert_operator PlayerSearch.hands_rank(right_left), :<, PlayerSearch.hands_rank(left_right)
    assert_nil PlayerSearch.hands_rank(Player.new)
  end

  test "ordered by role puts players, then staff, then managers, then the rest" do
    @imazu.update!(role: "マネージャー")
    @old.update!(role: "特別要員")

    assert_equal [ "落合 智哉", "日野 愛郎", "今津 慶介", "山田 太郎" ], PlayerSearch.new.ordered(sort: "role", direction: "asc").map(&:name)
  end
end
