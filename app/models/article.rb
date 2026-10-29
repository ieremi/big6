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
      slug: "strength-50-years", title: "この50年の強さの推移", published_on: Date.new(2026, 10, 29),
      description: "1977年から、シーズンの終わりの6大学の強さ（平均的な相手に勝つ確率）の移り変わり。年代ごとの平均と、各大学がいちばん強かった・弱かったシーズン。"
    ),
    Entry.new(
      slug: "strength-spread", title: "強さの差がいちばん小さかったシーズン、大きかったシーズン", published_on: Date.new(2026, 10, 23),
      description: "シーズンの終わりの6大学の強さの散らばり（分散）が、いちばん小さかったシーズンと大きかったシーズン。東大を除いた5大学でも。"
    ),
    Entry.new(
      slug: "draft-2026", title: "2026年ドラフト会議と東京六大学", published_on: Date.new(2026, 10, 23),
      description: "2026年のプロ野球ドラフト会議で、東京六大学からプロ野球志望届を出した選手と指名の結果、在学中の優勝回数。"
    )
  ].freeze

  def self.all
    ALL.sort_by { |entry| [ entry.published_on, entry.slug ] }.reverse
  end

  def self.find(slug)
    ALL.find { |entry| entry.slug == slug.to_s } or raise ActiveRecord::RecordNotFound, "no article #{slug}"
  end
end
