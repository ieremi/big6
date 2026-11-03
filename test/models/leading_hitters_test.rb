require "test_helper"

class LeadingHittersTest < ActiveSupport::TestCase
  setup do
    Player.create!(scorebook_id: 1, university: universities(:one), name: "単季", enter_year: 1933, role: "選手")
    Player.create!(scorebook_id: 2, university: universities(:two), name: "一年秋", enter_year: 2024, role: "選手")
    Player.create!(scorebook_id: 3, university: universities(:one), name: "予科", enter_year: 2020, role: "選手")
  end

  def champions
    stub_method(LeadingHitters, :path, -> { file_fixture("leading_hitters_test.yml") }) { LeadingHitters.all }
  end

  test "each champion's year is counted from the entry year, the spring and autumn of it the 1年" do
    assert_equal [ nil, 1, 1, 2, nil ], champions.map(&:grade) # not in the 名鑑; 1933; 2024 autumn; 2025 spring; six years on
    assert_equal [ "単季", "一年秋" ], champions.select(&:freshman?).map(&:name)
  end

  test "a champion has the season's title, the average and the university" do
    single, autumn = champions.values_at(1, 2)

    assert_equal [ "1933年", "2024年秋季" ], [ single.season_title, autumn.season_title ]
    assert_in_delta 16.0 / 34, autumn.average
    assert_equal universities(:two), autumn.university
  end

  test "the season being played is ranked the league's way, until its champion is listed" do
    game = Game.where(season: seasons(:one)).order(:played_on).first
    player = Player.create!(scorebook_id: 4, university: game.team0, name: "新人", enter_year: 2026, role: "選手")
    BattingLine.create!(game:, player:, university: game.team0, pa: 4, ab: 4, hits: 3)

    current = LeadingHitters.current(champions)

    assert_equal seasons(:one), current.season
    assert_equal [ [ 1, "新人" ] ], current.entries.map { |entry| [ entry.rank, entry.player.name ] }
    assert_nil LeadingHitters.current(champions + [ champions.last.with(year: 2026, term: "spring") ])
  end
end
