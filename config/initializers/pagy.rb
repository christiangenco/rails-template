require "pagy/extras/overflow"

Pagy::DEFAULT.merge!(
  limit: 25,
  size: 7,
  overflow: :last_page
)
