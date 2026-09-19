require "test_helper"

class GdpPerCapitaTest < ActiveSupport::TestCase
  test "returns a positive US dollar figure for a published year" do
    assert_operator GdpPerCapita.for_year(2000), :>, 0
  end

  test "returns nil before the World Bank series starts in 1960" do
    assert_nil GdpPerCapita.for_year(1959)
  end

  test "returns nil for a year with no figure yet" do
    assert_nil GdpPerCapita.for_year(2100)
  end
end
