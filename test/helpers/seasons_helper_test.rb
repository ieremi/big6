require "test_helper"

class SeasonsHelperTest < ActionView::TestCase
  test "strength_figure shows a chance as a percentage, with its odds and log odds hidden beside it" do
    html = Nokogiri::HTML.fragment(strength_figure(0.8))

    assert_equal [ [ "chance", "80%", false ], [ "odds", "4.00", true ], [ "logit", "+1.39", true ] ],
      html.css("span[data-view-switch-target=panel]").map { |span| [ span["data-view"], span.text, span.key?("hidden") ] }
  end

  test "strength_figure gives an average side's log odds no sign" do
    assert_includes strength_figure(0.5), ">0.00<"
    assert_includes strength_figure(0.2), ">-1.39<"
  end

  test "with_strength_figures turns each {59} in a text into a strength_figure and escapes the rest" do
    html = with_strength_figures("<b>平均{50}、最高{80}")

    assert html.html_safe?
    assert html.start_with?("&lt;b&gt;平均<span")
    assert_equal %w[50% 80%], Nokogiri::HTML.fragment(html).css("span[data-view=chance]").map(&:text)
    assert_equal %w[1.00 4.00], Nokogiri::HTML.fragment(html).css("span[data-view=odds]").map(&:text)
  end

  def comeback_of(count:, last: [ 1981, 1 ], rank: 1, tied: false, since: nil, longest: nil, kind: StreakRecords::COMEBACK_KINDS.find { |k| k.key == :a_class })
    StreakRecords::Comeback.new(university: University.new(short_name: "東大"), kind:, opponent: nil, count:, last: (last if count),
      status: :decided, rank: (rank if count), tied:, since:, longest:)
  end

  test "comeback_text says how long since, or that it's the first since 1950" do
    assert_equal "Aクラス（3位以上）　92季ぶり（前回1981年春）", comeback_text(comeback_of(count: 92))
    assert_equal "Aクラス（3位以上）　1950年以降初", comeback_text(comeback_of(count: nil))
  end

  test "comeback_notes ranks a gap only in the top ten, and says since when and the longest" do
    hosei, tokyo = University.new(short_name: "法大"), University.new(short_name: "東大")
    run = StreakRecords::Run.new(university_id: 1, opponent_id: 2, from: [ 1953, 1 ], to: [ 1993, 2 ], count: 81)

    assert_equal "1950年以降、6校のAクラス（3位以上）までの間隔のなかで2番目に長い（タイ）。1993年秋の東大（法大から81季ぶり）以来。",
      comeback_notes(comeback_of(count: 81, rank: 2, tied: true, since: [ run, tokyo, hosei ]))
    assert_equal "最長は1993年秋の東大（法大から81季ぶり）。", comeback_notes(comeback_of(count: 6, rank: 11, longest: [ run, tokyo, hosei ]))
    assert_equal "", comeback_notes(comeback_of(count: nil))
  end
end
