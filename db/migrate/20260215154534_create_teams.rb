class CreateTeams < ActiveRecord::Migration[8.1]
  def change
    create_table :teams do |t|
      t.string :name
      t.references :owner, null: true, foreign_key: { to_table: :users }
      t.integer :kind

      t.timestamps
    end
  end
end
