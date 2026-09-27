require "test_helper"

class DeveloperDocTest < ActiveSupport::TestCase
  test "the index is the README, and a page is found by its plain name only" do
    assert DeveloperDoc.find(nil).index?
    assert DeveloperDoc.find("index").index?
    assert_equal "league-site-game-page", DeveloperDoc.find("league-site-game-page").name
    assert_nil DeveloperDoc.find("no-such-page")
    assert_nil DeveloperDoc.find("../CLAUDE")
    assert_nil DeveloperDoc.find("Gemfile")
  end

  test "every page is listed, the README first" do
    docs = DeveloperDoc.all

    assert docs.first.index?
    assert_includes docs.map(&:name), "league-site-game-page"
  end

  test "a page has its title from its first heading, and a summary from its first paragraph" do
    doc = DeveloperDoc.find("league-site-game-page")

    assert_equal "連盟公式サイト（big6.gr.jp）の試合ページのURL", doc.title
    assert doc.summary.start_with?("東京六大学野球連盟の公式サイトには")
    assert_equal "/developers/league-site-game-page", doc.site_path
  end

  test "links between the pages point at the site, other files of the repository at GitHub, and outside links open apart" do
    html = Nokogiri::HTML::DocumentFragment.parse(DeveloperDoc.find(nil).html)

    assert html.at_css("a[href='/developers/league-site-game-page']")
    github = html.at_css("a[href='https://github.com/ieremi/big6/blob/main/CLAUDE.md']")
    assert_equal [ "_blank", "noopener noreferrer" ], [ github["target"], github["rel"] ]
  end

  test "tables are rendered, and raw HTML in the Markdown isn't let through" do
    assert_match "<table>", DeveloperDoc.find("league-site-game-page").html

    Tempfile.create([ "doc", ".md" ]) do |file|
      file.write("# T\n\n<script>alert(1)</script>\n")
      file.close
      assert_no_match "<script>", DeveloperDoc.new("test", Pathname.new(file.path)).html
    end
  end
end
