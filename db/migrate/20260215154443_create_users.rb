class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email
      t.string :name
      t.integer :sign_in_count, default: 0, null: false
      t.datetime :current_sign_in_at
      t.string :current_sign_in_ip
      t.datetime :last_sign_in_at
      t.string :last_sign_in_ip
      t.datetime :deleted_at
      t.datetime :deactivated_at

      t.timestamps
    end
    add_index :users, :email, unique: true
    add_index :users, :deleted_at
  end
end
