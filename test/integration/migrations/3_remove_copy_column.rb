class RemoveCopyColumn < ActiveRecord::Migration
  def self.up
    remove_copy_column :users, :password => :encrypted_password, :email => :email_address

    remove_column :users, :encrypted_password
    remove_column :users, :email_address
  end

  def self.down
    add_column :users, :encrypted_password, :string, :limit => 128, :default => "", :null => false
    add_column :users, :email_address, :limit => 100

    create_copy_column :users, :password => :encrypted_password, :email => :email_address
  end
end


