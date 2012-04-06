class CreateUser < ActiveRecord::Migration
  def self.up
    create_table "users", :force => true do |t|
      t.string "name"
      t.string "email",         :limit => 100
      t.string "password",      :limit => 100, :null => false
    end
  end

  def self.down
    drop_column "users"
  end
end


