#! /usr/bin/ruby
# This script will fill the test/fixtures/users.yml with 100k users

TOTAL_USERS = 100000

File.open("#{File.dirname(__FILE__)}/users.yml", 'w') do |f|
  TOTAL_USERS.times do |i|
    puts "Done : #{i} on #{TOTAL_USERS}" if i % 10000 == 0
    f.write <<-EOF
user_#{i}:
  name: #{i}
  email: #{i}@email.com
  password: psw_#{i}
    EOF
  end
end

