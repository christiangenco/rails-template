class ArticlesController < ApplicationController
  allow_unauthenticated_access

  def index
    @articles = Article.published
    respond_to do |format|
      format.html
      format.rss { render layout: false }
    end
  end

  def show
    @article = Article.find(params[:id])
  end
end
