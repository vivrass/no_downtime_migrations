class RemoveMirrorColumns < ActiveRecord::Migration
  def self.up
    # This is using the same parameters as the add_mirror_columns in step 2
    remove_mirror_columns :users, :password => :encrypted_password, :email => :email_address

    remove_column :users, :password
    remove_column :users, :email
  end

  def self.down
    add_column :users, :password, :string, :limit => 128, :default => "", :null => false
    add_column :users, :email,    :string, :limit => 100

    # NOTICE : In that rollback the columns are inverted.
    #          We want to mirror the new column on the old one since there is no values in the
    #          old columns anymore
    add_mirror_columns :users, :encrypted_password => :password, :email_address => :email
  end
end


