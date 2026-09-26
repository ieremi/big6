require "test_helper"

class RankingsHelperTest < ActionView::TestCase
  def seasons(*keys)
    keys.map { |key| year, term = key.split("-"); Season.new(year: year.to_i, term: term) }
  end

  test "season_ranges joins consecutive seasons into runs" do
    assert_equal [ "1925年春季〜1926年春季", "2010年秋季", "2014年春季〜2016年秋季" ],
      season_ranges(seasons("1925-spring", "1925-autumn", "1926-spring", "2010-autumn", "2014-spring", "2014-autumn", "2015-spring", "2015-autumn", "2016-spring", "2016-autumn"))
    assert_equal [], season_ranges([])
  end
end
