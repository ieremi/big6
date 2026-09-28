require "test_helper"

class SortOrderTest < ActiveSupport::TestCase
  COLUMNS = %w[date round attendance card].freeze

  def order(sort, direction = nil, **options)
    SortOrder.from_params(sort, direction, columns: COLUMNS, **options)
  end

  def pairs(order)
    order.map { |key| [ key.column, key.direction ] }
  end

  test "reads a single column as before, and comma-separated lists side by side" do
    assert_equal [ [ "date", "desc" ] ], pairs(order("date", "desc"))
    assert_equal [ [ "attendance", "desc" ], [ "date", "asc" ] ], pairs(order("attendance,date", "desc,asc"))
  end

  test "drops unknown and repeated columns, keeps at most three, and gives a column without a direction its default" do
    assert_equal [ [ "round", "asc" ], [ "date", "desc" ] ], pairs(order("bogus,round,date,round", "desc,asc,desc,desc"))
    assert_equal %w[date round attendance], order("date,round,attendance,card").columns
    assert_equal [ [ "attendance", "desc" ], [ "date", "asc" ] ],
      pairs(order("attendance,date", "sideways", default_direction: ->(column) { column == "attendance" ? "desc" : "asc" }))
    assert order(nil).empty?
    assert order([ "date" ], "asc").empty? # not a string: ignored
  end

  test "a click on another column makes it the first key and moves the others down, the fourth dropping off" do
    current = order("date,round,attendance", "asc,desc,asc")

    assert_equal [ [ "card", "asc" ], [ "date", "asc" ], [ "round", "desc" ] ], pairs(current.clicked("card", first: "asc"))
    assert_equal [ [ "attendance", "desc" ], [ "date", "asc" ], [ "round", "desc" ] ], pairs(current.clicked("attendance", first: "desc"))
  end

  test "a click on the first key reverses it and leaves the others" do
    current = order("date,round", "asc,desc")

    assert_equal [ [ "date", "desc" ], [ "round", "desc" ] ], pairs(current.clicked("date", first: "asc"))
  end

  test "with nothing asked for, the default key counts as the first one" do
    default = SortOrder::Key.new("date", "asc")

    assert_equal [ [ "date", "desc" ] ], pairs(SortOrder.new.clicked("date", first: "asc", default: default))
    assert_equal [ [ "round", "asc" ] ], pairs(SortOrder.new.clicked("round", first: "asc", default: default))
    assert_equal 1, SortOrder.new.or(default).rank("date")
    assert_nil SortOrder.new.or(default).rank("round")
  end

  test "goes back into a URL as the same two lists" do
    assert_equal({ "sort" => "attendance,date", "direction" => "desc,asc" }, order("attendance,date", "desc,asc").to_params)
    assert_equal({}, SortOrder.new.to_params)
  end
end
