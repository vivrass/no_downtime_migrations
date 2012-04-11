class CreateMirrorColumns < ActiveRecord::Migration
  def self.up
    add_column :users, :email_address,      :string, :limit => 100
    # test with empty default value
    add_column :users, :encrypted_password, :string, :limit => 128, :default => "", :null => false

    # This will mirror old columns (password, email) to new ones (encrypted_password, email_address) in the users table.
    add_mirror_columns :users, :password => :encrypted_password, :email => :email_address
  end

  def self.down
    # This is using the same parameters as the add_mirror_columns in migration
    remove_mirror_columns :users, :password => :encrypted_password, :email => :email_address

    remove_column :users, :encrypted_password
    remove_column :users, :email_address
  end
end

