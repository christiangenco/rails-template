class CreatePosts < ActiveRecord::Migration[8.1]
  def change
    create_table :posts do |t|
      t.string :title
      t.references :team, null: false, foreign_key: true, index: true
      t.references :created_by, foreign_key: { to_table: :users }, null: true

      t.timestamps
    end
  end
end
