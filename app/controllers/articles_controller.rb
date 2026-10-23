# The articles (読み物, Article): the list, and each one in its own view.
class ArticlesController < ApplicationController
  def index
    @articles = Article.all
  end

  def show
    @article = Article.find(params[:slug])
    render @article.template
  end
end
