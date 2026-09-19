require "test_helper"

class PlayerSyncTest < ActiveSupport::TestCase
  # Feeds PlayerSync canned API pages instead of calling Scorebook.
  class FakeSync < PlayerSync
    attr_reader :requests

    def initialize(pages:, **options)
      super(**options)
      @pages = pages
      @requests = []
    end

    private

    def fetch_page(year, page)
      @requests << [ year, page ]
      @pages.fetch([ year, page ], { "members" => [], "hasNextPage" => false })
    end
  end

  setup do
    @keio = University.create!(name: "慶應義塾大学", short_name: "慶大", slug: "keio", position: 3)
    @rikkio = University.create!(name: "立教大学", short_name: "立大", slug: "rikkio", position: 4)
  end

  def member(id, team_id, overrides = {})
    {
      "id" => id, "nameFull" => "落合 智哉", "nameFamilyKana" => "オチアイ", "nameFirstKana" => "トモヤ", "teamId" => team_id,
      "teamPositon" => "選手", "playerPosition" => "捕手", "battingHand" => "右", "pitchingHand" => "右", "highSchool" => "東邦",
      "univDiv" => "スポ", "gradeN" => 3, "enterYearWest" => 2023, "enrollmentActive" => 1
    }.merge(overrides)
  end

  def sync(pages, from_year: 2023, to_year: 2023)
    FakeSync.new(pages: pages, from_year: from_year, to_year: to_year, sleep_seconds: 0)
  end

  def undated_sync(pages)
    FakeSync.new(pages: pages, from_year: nil, to_year: nil, sleep_seconds: 0)
  end

  test "imports members with their basic fields" do
    result = sync({ [ 2023, 1 ] => { "members" => [ member(20236010, 6) ], "hasNextPage" => false } }).call

    assert_equal({ imported: 1, skipped: 0 }, result)
    player = Player.find_by!(scorebook_id: 20236010)
    assert_equal @rikkio, player.university
    assert_equal [ "落合 智哉", "オチアイ トモヤ", 2023, "選手", "捕手", "右", "右", "東邦", "スポ", 3, 1 ],
      player.attributes.values_at("name", "name_kana", "enter_year", "role", "position", "batting_hand", "pitching_hand", "high_school", "faculty", "grade", "enrollment_status")
  end

  test "follows pagination until there is no next page" do
    pages = {
      [ 2023, 1 ] => { "members" => [ member(1, 2, "nameFull" => "今津 慶介") ], "hasNextPage" => true },
      [ 2023, 2 ] => { "members" => [ member(2, 2, "nameFull" => "藤森 康淳") ], "hasNextPage" => false }
    }
    fake = sync(pages)

    assert_equal({ imported: 2, skipped: 0 }, fake.call)
    assert_equal [ [ 2023, 1 ], [ 2023, 2 ] ], fake.requests
  end

  test "requests every year in the range" do
    fake = sync({}, from_year: 2021, to_year: 2023)
    fake.call

    assert_equal [ [ 2021, 1 ], [ 2022, 1 ], [ 2023, 1 ] ], fake.requests
  end

  test "skips members of unknown teams and members without a name" do
    pages = { [ 2023, 1 ] => { "members" => [
      member(1, 6), member(2, 99), member(3, 6, "nameFull" => nil)
    ], "hasNextPage" => false } }

    assert_equal({ imported: 1, skipped: 2 }, sync(pages).call)
    assert_equal [ 1 ], Player.pluck(:scorebook_id)
  end

  test "re-running updates existing players instead of duplicating them" do
    sync({ [ 2023, 1 ] => { "members" => [ member(20236010, 6, "highSchool" => "東邦") ], "hasNextPage" => false } }).call
    sync({ [ 2023, 1 ] => { "members" => [ member(20236010, 6, "highSchool" => "東邦高校", "gradeN" => 4) ], "hasNextPage" => false } }).call

    assert_equal 1, Player.count
    assert_equal [ "東邦高校", 4 ], Player.first.attributes.values_at("high_school", "grade")
  end

  test "blank optional fields are stored as nil" do
    pages = { [ 2023, 1 ] => { "members" => [ member(5, 6, "nameFamilyKana" => nil, "nameFirstKana" => nil, "highSchool" => "", "playerPosition" => nil) ], "hasNextPage" => false } }
    sync(pages).call

    player = Player.find_by!(scorebook_id: 5)
    assert_nil player.name_kana
    assert_nil player.high_school
    assert_nil player.position
  end

  test "call_undated pages through every member but imports only those without an entry year" do
    pages = {
      [ nil, 1 ] => { "members" => [ member(1, 2), member(2, 2, "nameFull" => "日野 愛郎", "teamPositon" => "部長", "enterYearWest" => nil) ], "hasNextPage" => true },
      [ nil, 2 ] => { "members" => [ member(3, 6, "nameFull" => "山本 雄一郎", "teamPositon" => "部長", "enterYearWest" => nil), member(4, 6) ], "hasNextPage" => false }
    }
    fake = undated_sync(pages)

    assert_equal({ imported: 2, skipped: 0 }, fake.call_undated)
    assert_equal [ [ nil, 1 ], [ nil, 2 ] ], fake.requests
    assert_equal [ 2, 3 ], Player.order(:scorebook_id).pluck(:scorebook_id)
    assert_nil Player.find_by!(scorebook_id: 2).enter_year
    assert_equal "部長", Player.find_by!(scorebook_id: 2).role
  end
end
