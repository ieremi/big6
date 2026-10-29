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
end
