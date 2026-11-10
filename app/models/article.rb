# The site's articles (読み物): pieces written around the league's data, each
# at /articles/<slug> with its own view (app/views/articles/<slug, underscored>),
# listed at /articles, newest first. Kept here rather than in the database: an
# article is written with its view, and is added to the list with it.
class Article
  Entry = Struct.new(:slug, :title, :published_on, :description, keyword_init: true) do
    def template
      "articles/#{slug.underscore}"
    end
  end

  ALL = [
    Entry.new(
      slug: "schedule-2027-spring", title: "2027年春季の日程を予想する", published_on: Date.new(2026, 11, 9),
      description: "日程の慣例がすべて守られるとして、2027年春季リーグ戦の開幕日、各週のカードの順番、終盤がシングルカードになるかを予想。早慶法が2位で並んだときの前例も。"
    ),
    Entry.new(
      slug: "senior-appearances", title: "4年生のスタメン・ベンチ入り", published_on: Date.new(2026, 11, 4),
      description: "2026年の4年生（2023年入学）のうち、リーグ戦で1回でもスタメンに入った選手、ベンチ入りだけの選手、ベンチ入りしなかった選手の人数と割合を大学ごとに。帯グラフつき。"
    ),
    Entry.new(
      slug: "autumn-2026-highlights", title: "2026年秋季 明大・法大・立大・東大のよかったところ", published_on: Date.new(2026, 11, 3),
      description: "2026年秋季のリーグ戦を終えた明大・法大・立大・東大の、打率・防御率・打数・投球回・出場試合数ですぐれた選手や、春からのチーム成績ののび、観衆の増えたところ。"
    ),
    Entry.new(
      slug: "echigo-batting-title", title: "越後選手が首位打者にならないパターン", published_on: Date.new(2026, 11, 3),
      description: "2026年秋季、打率1位の立大・越後 駿祐（1年）が首位打者を逃すのはどんなときか。早慶戦の打者が抜くのに必要な安打数。"
    ),
    Entry.new(
      slug: "freshman-leading-hitters", title: "1年生の首位打者", published_on: Date.new(2026, 11, 3),
      description: "東京六大学野球のリーグ戦で、1年生で首位打者になった選手。1925年秋からの首位打者の学年ごとの人数と、今季の打率上位の1年生も。"
    ),
    Entry.new(
      slug: "home-runs-per-season", title: "シーズンの本塁打数", published_on: Date.new(2026, 11, 1),
      description: "1シーズンの本塁打の本数（6大学の合計）の最少・最多・平均・標準偏差。1試合あたりの本数と、年代ごとの移り変わりも。"
    ),
    Entry.new(
      slug: "strength-postwar", title: "戦後の強さの推移", published_on: Date.new(2026, 10, 29),
      description: "戦後、シーズンの終わりの6大学の強さ（平均的な相手に勝つ確率）の移り変わり。年代ごとの平均と、各大学がもっとも強かった・弱かったシーズン。"
    ),
    Entry.new(
      slug: "strength-spread", title: "強さの差がもっとも小さかったシーズン、大きかったシーズン", published_on: Date.new(2026, 10, 23),
      description: "シーズンの終わりの6大学の強さの散らばり（分散）が、もっとも小さかったシーズンと大きかったシーズン。東大を除いた5大学でも。"
    ),
    Entry.new(
      slug: "draft-2026", title: "2026年ドラフト会議と東京六大学", published_on: Date.new(2026, 10, 23),
      description: "2026年のプロ野球ドラフト会議で、東京六大学からプロ野球志望届を出した選手と指名の結果、在学中の優勝回数。"
    )
  ].freeze

  # Articles that have moved, by their old slug: the old URL is sent on to the new one.
  MOVED = { "strength-50-years" => "strength-postwar" }.freeze

  def self.all
    ALL.sort_by { |entry| [ entry.published_on, entry.slug ] }.reverse
  end

  def self.find(slug)
    ALL.find { |entry| entry.slug == slug.to_s } or raise ActiveRecord::RecordNotFound, "no article #{slug}"
  end
end
