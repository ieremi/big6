require "test_helper"

class NewsControllerTest < ActionDispatch::IntegrationTest
  def publish(title, at:, game: nil)
    suggestion = game && FixSuggestion.create!(kind: "misfiled_lines", key: "misfiled_lines #{title}", confidence: "likely", status: "approved",
      university: game.team1, game: game)
    Announcement.create!(title: title, body: "#{title}の本文（https://big6scorebook.jp/game/2026081001）", published_at: at, fix_suggestion: suggestion)
  end

  test "the notices are listed newest first, each linked to its game" do
    publish("古いおしらせ", at: 3.days.ago)
    publish("新しいおしらせ", at: 1.day.ago, game: games(:one))

    get news_path

    assert_response :success
    assert_equal [ "新しいおしらせ", "古いおしらせ" ], css_select(".news-list h3").map(&:text)
    assert_select ".news-list p", "新しいおしらせの本文（https://big6scorebook.jp/game/2026081001）"
    assert_select ".news-list p a[href=?][target=_blank]", "https://big6scorebook.jp/game/2026081001", minimum: 1
    assert_select ".news-list a[href=?]", matchup_game_path("alpha", "beta", 2026, "spring", 1), text: "試合のページへ →"
  end

  test "the page says so when there are no notices" do
    get news_path

    assert_select ".news-list", 0
    assert_select "p.muted", "おしらせはありません。"
  end

  test "the home page shows the latest three notices and links to all of them" do
    4.times { |i| publish("おしらせ#{i}", at: (4 - i).days.ago) }

    get root_path

    assert_equal %w[おしらせ3 おしらせ2 おしらせ1], css_select(".news-list h3").map(&:text)
    assert_select "a[href=?]", news_path, text: "すべてのおしらせ →"
  end

  test "the home page has no notices section while there are none" do
    get root_path

    assert_select "h2", text: "おしらせ", count: 0
  end
end
