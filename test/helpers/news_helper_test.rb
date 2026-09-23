require "test_helper"

class NewsHelperTest < ActionView::TestCase
  test "linked_text makes each URL a link that opens in a new tab, ending where a full-width bracket starts" do
    html = linked_text("この試合（https://big6scorebook.jp/game/2025100502）と別の試合（https://big6scorebook.jp/game/2025100501）に")

    assert_equal "この試合（<a target=\"_blank\" rel=\"noopener noreferrer\" href=\"https://big6scorebook.jp/game/2025100502\">https://big6scorebook.jp/game/2025100502</a>）" \
      "と別の試合（<a target=\"_blank\" rel=\"noopener noreferrer\" href=\"https://big6scorebook.jp/game/2025100501\">https://big6scorebook.jp/game/2025100501</a>）に", html
    assert html.html_safe?
  end

  test "linked_text escapes everything else" do
    html = linked_text(%(<script>alert(1)</script> https://example.com/?a=1&b=2))

    assert_includes html, "&lt;script&gt;alert(1)&lt;/script&gt;"
    assert_includes html, %(href="https://example.com/?a=1&amp;b=2")
  end

  test "linked_text leaves text without URLs as it is" do
    assert_equal "補いました。", linked_text("補いました。")
    assert_equal "", linked_text(nil)
  end
end
