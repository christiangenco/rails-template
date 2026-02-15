class Post < ApplicationRecord
  belongs_to :team
  belongs_to :created_by, class_name: "User", optional: true

  has_rich_text :body
  has_one_attached :cover_image

  validates :title, presence: true

  scope :newest_first, -> { order(created_at: :desc) }
end
