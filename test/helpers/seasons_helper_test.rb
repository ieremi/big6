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
end
