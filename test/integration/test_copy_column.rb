require 'helper'
require 'logger'

class TestCopyColumn < Test::Unit::TestCase
  MIGRATION_PATH = "#{File.dirname(__FILE__)}/migrations"
  MIGRATION_CREATE_USER_VERSION        = 1;
  MIGRATION_CREATE_COPY_COLUMN_VERSION = 2;
  MIGRATION_REMOVE_COPY_COLUMN_VERSION = 3;

  context "given a MySQL adapter" do
    setup do
      configure_adapter
    end

    should "Have the expected behaviour" do
      assert_equal 0, ActiveRecord::Base.connection.execute("SHOW TRIGGERS;").count

      old_email = "john@gmail.com"
      old_password = "psw"
      @user = User.create!(:name => "John Doe", :email => old_email, :password => old_password)

      assert !@user.respond_to?(:email_address)
      assert !@user.respond_to?(:encrypted_password)


      ActiveRecord::Migrator.migrate(MIGRATION_PATH, MIGRATION_CREATE_COPY_COLUMN_VERSION)
      User.reset_column_information

      assert_equal 2, ActiveRecord::Base.connection.execute("SHOW TRIGGERS;").count
      @user = User.last

      # Verify first copy
      assert_equal old_email,    @user.email
      assert_equal old_email,    @user.email_address
      assert_equal old_password, @user.password
      assert_equal old_password, @user.encrypted_password

      # Verify modification of old column
      new_email = "john_email@gmail.com"
      new_password = "psw_password"
      @user.email = new_email
      @user.password = new_password
      @user.save!
      @user = User.last

      assert_equal new_email,    @user.email
      assert_equal new_email,    @user.email_address
      assert_equal new_password, @user.password
      assert_equal new_password, @user.encrypted_password

      # Verify modification of new column
      new_email = "john_email_address@gmail.com"
      new_password = "psw_encrypted_password"
      @user.email_address = new_email
      @user.encrypted_password = new_password
      @user.save!
      @user = User.last

      assert_equal new_email,    @user.email
      assert_equal new_email,    @user.email_address
      assert_equal new_password, @user.password
      assert_equal new_password, @user.encrypted_password


      ActiveRecord::Migrator.migrate(MIGRATION_PATH, MIGRATION_REMOVE_COPY_COLUMN_VERSION)
      User.reset_column_information
      assert_equal 0, ActiveRecord::Base.connection.execute("SHOW TRIGGERS;").count
    end

  end

  private
  def configure_adapter
    db_name = 'no_downtime_migrations_test'
    config = {:database => db_name, :username => 'root', :adapter => "mysql", :host => 'localhost'}

    ret = `echo "drop database if exists #{db_name}; create database #{db_name};" | mysql -u root`
    raise "error creating database: #{ret}" unless $?.exitstatus == 0

    # Arel has an issue in that it keeps using original connection for quoting,
    # etc. (which breaks stuff) unless you do this:
    ActiveRecord::SchemaDumper.previous_schema = nil
    Arel::Visitors::ENGINE_VISITORS.delete(ActiveRecord::Base) if defined?(Arel)
    ActiveRecord::Base.establish_connection(config)
    ActiveRecord::Base.logger = Logger.new('/dev/null')

    ActiveRecord::Migrator.migrate(MIGRATION_PATH, MIGRATION_CREATE_USER_VERSION)
    User.reset_column_information
  end

end

class User < ActiveRecord::Base
end
