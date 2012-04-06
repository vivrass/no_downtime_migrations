class CreateUser < ActiveRecord::Migration
  def self.up
    create_table "users", :force => true do |t|
      t.string "name"
      t.string "email",         :limit => 100
      t.string "password",      :limit => 100, :null => false
    end

    # Debug triggers
    #sql += "INSERT INTO debug_triggers (new_column, old_column, new_source, old_source, new_destination, old_destination) VALUES ('#{source_column}', '#{destination_column}', NEW.#{source_column}, OLD.#{source_column}, NEW.#{destination_column}, OLD.#{destination_column});"
    create_table "debug_triggers", :force => true do |t|
      t.string "new_column"
      t.string "old_column"
      t.string "new_source"
      t.string "old_source"
      t.string "new_destination"
      t.string "old_destination"
    end
  end

  def self.down
    drop_table "users"
    drop_table "tests"
  end
end


