class PostsController < ApplicationController
  include TeamScoped

  before_action :set_post, only: [:show, :edit, :update, :destroy]

  def index
    @pagy, @posts = pagy(Current.team.posts.newest_first, limit: 10)
  end

  def show
  end

  def new
    @post = Current.team.posts.build
  end

  def create
    @post = Current.team.posts.build(post_params)
    @post.created_by = current_user

    if @post.save
      redirect_to post_path(@post, team_id: Current.team.id), notice: "Post created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @post.update(post_params)
      redirect_to post_path(@post, team_id: Current.team.id), notice: "Post updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @post.destroy!
    redirect_to posts_path(team_id: Current.team.id), notice: "Post deleted."
  end

  private

  def set_post
    @post = Current.team.posts.find(params[:id])
  end

  def post_params
    params.require(:post).permit(:title, :body, :cover_image)
  end
end
