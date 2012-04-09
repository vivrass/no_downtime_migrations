class User < ActiveRecord::Base
  attr_accessible :email, :email_address, :name, :password, :encrypted_password

  paginates_per 250 # kaminari
end
