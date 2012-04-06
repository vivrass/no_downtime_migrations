require 'helper'
require 'logger'

class TestMirrorColumns < Test::Unit::TestCase
  MIGRATION_PATH = "#{File.dirname(__FILE__)}/migrations"
  MIGRATION_CREATE_USER_VERSION        = 1;
  MIGRATION_CREATE_MIRROR_COLUMN_VERSION = 2;
  MIGRATION_REMOVE_MIRROR_COLUMN_VERSION = 3;

  context "given a MySQL adapter" do
    setup do
      configure_adapter
    end

    # Test everything in the same test so we don't depend on schema state before each state (i.e. faster tests)
    should "Have the expected behaviour" do
      assert_equal 0, ActiveRecord::Base.connection.execute("SHOW TRIGGERS;").count

      old_name = "John Doe"
      old_email = "john@gmail.com"
      old_password = "psw"
      @user = User.create!(:name => old_name, :email => old_email, :password => old_password)

      assert !@user.respond_to?(:email_address)
      assert !@user.respond_to?(:encrypted_password)


      ActiveRecord::Migrator.migrate(MIGRATION_PATH, MIGRATION_CREATE_MIRROR_COLUMN_VERSION)
      User.reset_column_information

      assert_equal 2, ActiveRecord::Base.connection.execute("SHOW TRIGGERS;").count
      @user = User.last

      # Verify first copy
      test_user @user, :name => old_name, :email => old_email, :password => old_password

      # Verify modification of old column
      new_email = "john_email@gmail.com"
      new_password = "psw_password"
      @user.email = new_email
      @user.password = new_password
      @user.save!
      @user = User.last

      test_user @user, :name => old_name, :email => new_email, :password => new_password

      # Verify modification of new column
      new_email = "john_email_address@gmail.com"
      new_password = "psw_encrypted_password"
      @user.email_address = new_email
      @user.encrypted_password = new_password
      @user.save!
      @user = User.last

      test_user @user, :name => old_name, :email => new_email, :password => new_password

      # Verify insertion with old column
      name = "create_old"
      email = "create_old_email@gmail.com"
      password = "create_old_password"
      @user = User.create!(:name => name, :email => email, :password => password).reload

      test_user @user, :name => name, :email => email, :password => password

      # Verify insertion with new column
      name = "create_new"
      email = "create_new_email@gmail.com"
      password = "create_new_password"
      @user = User.create!(:name => name, :email => email, :password => password).reload

      test_user @user, :name => name, :email => email, :password => password

      # Verify modification of old column with NULL
      name = "create_null_old"
      email = nil
      new_email = "create_null_email"
      password = ''
      new_password = "create_null_old_password"
      @user = User.create!(:name => name, :email => email, :password => password).reload
      test_user @user, :name => name, :email => email, :password => password

      @user.email = new_email
      @user.password = new_password
      @user.save!
      @user = User.last
      test_user @user, :name => name, :email => new_email, :password => new_password

      # Verify modification of new column with NULL
      name = "create_null_new"
      email = nil
      new_email = "create_null_email"
      password = ''
      password = "create_null_new_password"
      @user = User.create!(:name => name, :email => email, :password => password).reload
      test_user @user, :name => name, :email => email, :password => password

      @user.email_address = new_email
      @user.encrypted_password = new_password
      @user.save!
      @user = User.last
      test_user @user, :name => name, :email => new_email, :password => new_password


      # Verify modification of old column to NULL
      name = "create_old_to_null"
      email = "create_old_email_to_null"
      new_email = nil
      password = "create_old_password_to_null"
      new_password = ''
      @user = User.create!(:name => name, :email => email, :password => password).reload
      test_user @user, :name => name, :email => email, :password => password

      @user.email = new_email
      @user.password = new_password
      @user.save!
      @user = User.last
      test_user @user, :name => name, :email => new_email, :password => new_password

      # Verify modification of new column with NULL
      name = "create_new_to_null"
      email = "create_new_email_to_null"
      new_email = nil
      password = "create_new_password_to_null"
      new_password = ''
      @user = User.create!(:name => name, :email => email, :password => password).reload
      test_user @user, :name => name, :email => email, :password => password

      @user.email_address = new_email
      @user.encrypted_password = new_password
      @user.save!
      @user = User.last
      test_user @user, :name => name, :email => new_email, :password => new_password

      # Verify drop
      ActiveRecord::Migrator.migrate(MIGRATION_PATH, MIGRATION_REMOVE_MIRROR_COLUMN_VERSION)
      User.reset_column_information
      assert_equal 0, ActiveRecord::Base.connection.execute("SHOW TRIGGERS;").count
    end

  end

  private

  def test_user(user, params)
    assert_equal params[:name], user.name

    assert_equal params[:email], user.email
    assert_equal params[:email], user.email_address

    assert_equal params[:password], user.password
    assert_equal params[:password], user.encrypted_password
  end

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
