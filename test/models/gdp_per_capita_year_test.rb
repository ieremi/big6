require "test_helper"

class GdpPerCapitaYearTest < ActiveSupport::TestCase
  test "returns the US dollar figure for a year that has one" do
    assert_equal 39_000, GdpPerCapitaYear.usd_for(2000)
  end

  test "returns nil for a year with no figure" do
    assert_nil GdpPerCapitaYear.usd_for(1959)
  end
end
