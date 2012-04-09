# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 3) do

  create_table "debug_triggers", :force => true do |t|
    t.string "new_column"
    t.string "old_column"
    t.string "new_source"
    t.string "old_source"
    t.string "new_destination"
    t.string "old_destination"
  end

  create_table "users", :force => true do |t|
    t.string "name"
    t.string "email",    :limit => 100
    t.string "password", :limit => 100, :null => false
  end

end
