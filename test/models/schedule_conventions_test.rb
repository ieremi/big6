require "test_helper"

class ScheduleConventionsTest < ActiveSupport::TestCase
  LETTERS = { w: "waseda", k: "keio", m: "meiji", h: "hosei", r: "rikkio", t: "tokyo" }.freeze

  setup do
    @universities = LETTERS.values.each_with_index.to_h do |slug, index|
      [ slug, University.find_by(slug: slug) || University.create!(name: slug, short_name: slug, slug: slug, position: index + 11) ]
    end
  end

  def u(letter)
    @universities.fetch(LETTERS.fetch(letter))
  end

  # The previous season's places from a string like "wkmhrt" (first to last; "m=h" tied).
  def places(order)
    order.scan(/[a-z](?:=[a-z])*/).map { |place| place.delete("=").chars.map { |l| u(l.to_sym) } }
  end

  # Weeks from strings of cards like "wm rt".
  def weeks(*week_strings)
    week_strings.map { |cards| cards.split.map { |card| card.chars.map { |l| u(l.to_sym) } } }
  end

  def check(previous, *week_strings)
    ScheduleConventions::Check.new(weeks(*week_strings), places(previous))
  end

  def result(key, check)
    check.result(ScheduleConventions::RULES.find { |rule| rule.key == key })
  end

  # A season after 明大 won, 早大 2nd, then 法立東慶 (MHRT order: m h r t).
  def after_meiji_first(week1: "mt kr")
    check("mwhrtk", week1, "hr wt", "mk ht", "mr kt", "hk rw", "kh wm", "mh rt", "wk")
  end

  test "checks the first week from the previous season's standings" do
    season = after_meiji_first
    assert_equal :followed, result("m1", season)   # 明大 against the 4th of MHRT (東大)
    assert_equal :followed, result("wk2", season)  # 早大 2nd: 慶大 plays
    assert_nil result("wk3", season)
    assert_nil result("wk1", season)
    assert_equal :followed, result("first", season)

    season = after_meiji_first(week1: "mh wt")
    assert_equal :broken, result("m1", season)
    assert_equal :broken, result("wk2", season)
  end

  test "checks the later weeks" do
    season = after_meiji_first
    assert_equal :followed, result("w2", season)  # 法 v 立, MHRT's 2nd v 3rd
    assert_equal :followed, result("w4", season)  # week 4 is week 1's four again
    assert_equal :broken, result("w5", season)    # week 5 isn't week 2's four
    assert_equal :followed, result("w7", season)  # 明 v 法, 立 v 東

    good = check("mwhrtk", "mt kr", "hr wt", "mk ht", "mk rt", "hw rk", "km wh", "mh rt", "wk")
    assert_equal :followed, result("w4", good)
    assert_equal :followed, result("w6", good)    # 早慶 against 明 and 法
    assert_equal :followed, result("w7", good)    # 明 v 法, 立 v 東
  end

  test "asks for weeks of 明法立東 alone when 早慶 won the previous season" do
    after_waseda = check("wmhrtk", "wm kt", "hr mt", "mh rt", "wh km", "hr mt", "mr ht", "kr wt", "wk")
    assert_equal :followed, result("mhrt", after_waseda)
    assert_equal :followed, result("wk1", after_waseda)
  end

  test "can't tell when the rule needs two universities that were tied" do
    tied = check("m=hwrtk", "mt kr", "hr wt", "mk ht", "mr kt", "hk rw", "kh wm", "mh rt", "wk")
    assert_equal :unknown, result("first", tied)  # 明 and 法 both first
    assert_equal :unknown, result("w2", tied)     # MHRT's 2nd: 明 or 法
  end

  test "works out one season from its games and the previous season's alone" do
    assert_nil ScheduleConventions.for(Season.create!(year: 1990, term: "spring"))
  end
end
