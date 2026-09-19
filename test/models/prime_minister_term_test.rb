require "test_helper"

class PrimeMinisterTermTest < ActiveSupport::TestCase
  test "returns the single Prime Minister in office for the whole range" do
    names = PrimeMinisterTerm.serving_between(Date.new(1995, 4, 8), Date.new(1995, 5, 30)).map(&:name)

    assert_equal [ "村山富市" ], names
  end

  test "returns every Prime Minister in office during the range, oldest first" do
    names = PrimeMinisterTerm.serving_between(Date.new(2001, 4, 14), Date.new(2001, 6, 3)).map(&:name)

    assert_equal [ "森喜朗", "小泉純一郎" ], names
  end

  test "on the day a successor takes office only the successor counts" do
    names = PrimeMinisterTerm.serving_between(Date.new(1946, 5, 22), Date.new(1946, 5, 22)).map(&:name)

    assert_equal [ "吉田茂" ], names
  end

  test "a range ending the day before a successor takes office excludes the successor" do
    names = PrimeMinisterTerm.serving_between(Date.new(1946, 5, 1), Date.new(1946, 5, 21)).map(&:name)

    assert_equal [ "幣原喜重郎" ], names
  end

  test "the incumbent's open-ended term is still found" do
    names = PrimeMinisterTerm.serving_between(Date.new(2030, 1, 1), Date.new(2030, 1, 1)).map(&:name)

    assert_equal [ "高市早苗" ], names
  end

  test "returns nothing when there is no Prime Minister in office" do
    assert_empty PrimeMinisterTerm.serving_between(Date.new(1900, 1, 1), Date.new(1900, 1, 2))
  end

  test "returns nothing when the range is missing" do
    assert_empty PrimeMinisterTerm.serving_between(nil, nil)
  end
end
