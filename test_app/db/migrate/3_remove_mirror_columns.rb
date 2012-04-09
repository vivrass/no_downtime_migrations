class RemoveMirrorColumns < ActiveRecord::Migration
  def self.up
    remove_mirror_columns :users, :password => :encrypted_password, :email => :email_address

    remove_column :users, :password
    remove_column :users, :email
  end

  def self.down
    add_column :users, :password, :string, :limit => 128, :default => "", :null => false
    add_column :users, :email,    :string, :limit => 100

    execute "UPDATE users set password = encrypted_password, email = email_email_address" # Refill the old columns
    add_mirror_columns :users, :password => :encrypted_password, :email => :email_address
  end
end


