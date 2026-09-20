require "test_helper"

class OgImagesTest < ActiveSupport::TestCase
  setup do
    @alpha = universities(:one)
    @beta = universities(:two)
  end

  def png?(bytes)
    bytes.b[0, 4] == "\x89PNG".b
  end

  test "each kind of image is a PNG" do
    assert png?(OgImages.university(@alpha))
    assert png?(OgImages.season(seasons(:one)))
    assert png?(OgImages.game(games(:one)))
    assert png?(OgImages.matchup(@alpha, @beta))
  end

  test "a matchup with an unknown period is the all-time image" do
    assert_equal OgImages.matchup(@alpha, @beta), OgImages.matchup(@alpha, @beta, period: "bogus")
    assert_equal OgImages.matchup(@alpha, @beta), OgImages.matchup(@alpha, @beta, period: nil)
  end

  test "a matchup's image depends on the period, year, and season asked for" do
    images = [ nil, "20", "10", "5", "r" ].map { |period| OgImages.matchup(@alpha, @beta, period: period) }
    by_year = OgImages.matchup(@alpha, @beta, year: 2026)
    by_season = OgImages.matchup(@alpha, @beta, season: seasons(:one))

    assert_equal 5, images.uniq.size, "each period has its own label, so its own image"
    assert_not_equal by_year, by_season
    assert_not_equal images.first, by_year
  end

  test "a season's label is drawn on the image and a blank label is the same as none" do
    assert_not_equal OgImages.season(seasons(:one)), OgImages.season(seasons(:one), label: "Champion")
    assert_equal OgImages.season(seasons(:one)), OgImages.season(seasons(:one), label: "")
  end

  test "every matchup period has a label" do
    assert_equal %w[all 20 10 5 r].sort, OgImages::MATCHUP_PERIOD_LABELS.keys.sort
  end
end
