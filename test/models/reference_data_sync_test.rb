require "test_helper"

class ReferenceDataSyncTest < ActiveSupport::TestCase
  # Feeds ReferenceDataSync canned rows instead of calling Wikidata/World Bank.
  class FakeSync < ReferenceDataSync
    def initialize(rows:, gdp:)
      @rows = rows
      @gdp = gdp
    end

    private

    def fetch_prime_minister_rows = @rows
    def fetch_gdp_by_year = @gdp
  end

  def row(name, start_on, end_on)
    { name: name, start_on: Date.iso8601(start_on), end_on: (Date.iso8601(end_on) if end_on) }
  end

  test "build_terms merges consecutive cabinets of the same person" do
    terms = ReferenceDataSync.build_terms([
      row("小泉純一郎", "2001-04-26", "2003-11-19"),
      row("小泉純一郎", "2003-11-19", "2005-09-21"),
      row("小泉純一郎", "2005-09-21", "2006-09-26"),
      row("安倍晋三", "2006-09-26", "2007-09-25")
    ])

    assert_equal [ [ "小泉純一郎", Date.new(2001, 4, 26), Date.new(2006, 9, 26) ], [ "安倍晋三", Date.new(2006, 9, 26), Date.new(2007, 9, 25) ] ],
      terms.map { |t| [ t[:name], t[:start_on], t[:end_on] ] }
  end

  test "build_terms keeps separate terms of the same person apart" do
    terms = ReferenceDataSync.build_terms([
      row("安倍晋三", "2006-09-26", "2007-09-25"),
      row("福田康夫", "2007-09-26", "2008-09-24"),
      row("安倍晋三", "2012-12-26", "2020-09-16")
    ])

    assert_equal %w[安倍晋三 福田康夫 安倍晋三], terms.map { |t| t[:name] }
  end

  test "build_terms sorts, drops acting Prime Ministers, and drops terms before the first season" do
    terms = ReferenceDataSync.build_terms([
      row("大平正芳", "1978-12-07", "1980-06-12"),
      row("伊東正義", "1980-06-12", "1980-07-17"),
      row("鈴木善幸", "1980-07-17", "1982-11-27"),
      row("原敬", "1918-09-29", "1921-11-04")
    ])

    assert_equal %w[大平正芳 鈴木善幸], terms.map { |t| t[:name] }
  end

  test "call replaces the stored data" do
    result = FakeSync.new(
      rows: [ row("吉田茂", "1946-05-22", "1947-05-24"), row("高市早苗", "2025-10-21", nil) ],
      gdp: { 1960 => 519, 1961 => 622 }
    ).call

    assert_equal({ prime_minister_terms: 2, gdp_years: [ 1960, 1961 ] }, result)
    assert_equal %w[吉田茂 高市早苗], PrimeMinisterTerm.order(:start_on).pluck(:name)
    assert_nil PrimeMinisterTerm.find_by!(name: "高市早苗").end_on
    assert_equal [ [ 1960, 519 ], [ 1961, 622 ] ], GdpPerCapitaYear.order(:year).pluck(:year, :usd)
  end

  test "call keeps the existing data when nothing was fetched" do
    terms_before = PrimeMinisterTerm.count
    gdp_before = GdpPerCapitaYear.count

    assert_raises(RuntimeError) { FakeSync.new(rows: [], gdp: { 1960 => 519 }).call }
    assert_raises(RuntimeError) { FakeSync.new(rows: [ row("吉田茂", "1946-05-22", nil) ], gdp: {}).call }

    assert_equal terms_before, PrimeMinisterTerm.count
    assert_equal gdp_before, GdpPerCapitaYear.count
  end
end
