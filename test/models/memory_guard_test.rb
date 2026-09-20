require "test_helper"

class MemoryGuardTest < ActiveSupport::TestCase
  # A reader that returns each of the given values in turn, then keeps the last.
  def reader_for(*values)
    queue = values.dup
    -> { queue.size > 1 ? queue.shift : queue.first }
  end

  test "is not exceeded while growth stays within the limit" do
    guard = MemoryGuard.new(growth_limit_mb: 100, reader: reader_for(200, 250, 300))

    assert_not guard.exceeded? # 250 - 200 = 50
    assert_not guard.exceeded? # 300 - 200 = 100, not past the limit
  end

  test "is exceeded once growth passes the limit" do
    guard = MemoryGuard.new(growth_limit_mb: 100, reader: reader_for(200, 301))

    assert guard.exceeded?
  end

  test "growth is measured from where the guard was created, not from zero" do
    guard = MemoryGuard.new(growth_limit_mb: 100, reader: reader_for(900, 950))

    assert_not guard.exceeded?
    assert_equal 50, guard.growth_mb
  end

  test "never trips where memory can't be read" do
    guard = MemoryGuard.new(growth_limit_mb: 0, reader: -> { nil })

    assert_not guard.exceeded?
    assert_nil guard.growth_mb
  end

  test "reads the real resident memory of this process" do
    rss = MemoryGuard.rss_mb

    assert_operator rss, :>, 0 if File.exist?("/proc/self/status")
    assert_nil rss unless File.exist?("/proc/self/status")
  end
end
