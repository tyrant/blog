class CreateUsers < ActiveRecord::Migration[6.1]
  def change
    create_table :users do |t|
      t.string :email
      t.string :name
      
      t.index :email
      t.index :name
      
      t.timestamps
    end
  end
end
