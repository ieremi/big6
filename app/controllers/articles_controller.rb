# The articles (読み物, Article): the list, and each one in its own view.
class ArticlesController < ApplicationController
  def index
    @articles = Article.all
  end

  # An article that has moved (Article::MOVED) is sent on to its new URL for good.
  def show
    if (moved = Article::MOVED[params[:slug]])
      redirect_to article_path(moved), status: :moved_permanently
      return
    end

    @article = Article.find(params[:slug])
    render @article.template
  end

  # The list's OG image, and each article's: its title over the site's stripes,
  # 「読み物」 under it (SiteOgImage, as the other pages').
  def index_og_image
    send_data SiteOgImage.new(title: "読み物").to_png, type: "image/png", disposition: "inline"
  end

  def og_image
    article = Article.find(Article::MOVED.fetch(params[:slug], params[:slug]))

    send_data SiteOgImage.new(title: article.title, subtitle: "読み物").to_png, type: "image/png", disposition: "inline"
  end
end
