require 'helper'
require 'logger'

class TestMirrorColumns < Test::Unit::TestCase
  MIGRATION_PATH = "#{File.dirname(__FILE__)}/../../test_app/db/migrate"
  MIGRATION_CREATE_USER_VERSION        = 1;
  MIGRATION_CREATE_MIRROR_COLUMN_VERSION = 2;
  MIGRATION_REMOVE_MIRROR_COLUMN_VERSION = 3;

  context "given a MySQL adapter" do
    setup do
      configure_adapter
    end

    # Test everything in the same test so we don't depend on schema state before each state (i.e. faster tests)
    should "Have the expected update behaviour" do
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

      @user = User.first
      assert !@user.respond_to?(:email)
      assert !@user.respond_to?(:password)
    end

    should "have the expected transition behaviour and support rollback" do
      NB_USERS = 10
      users_attributes = {}
      NB_USERS.times do |i|
        p = {:name => "name_#{i}", :email => "#{i}@email.com", :password => "psw_#{i}"}
        user = User.create!(p)
        users_attributes[user.id] = p
      end

      users_attributes[users_attributes.keys[0]] = {:name => "step_0", :email => "step_0@email.com", :password => "step_0_password"}
      User.find(users_attributes.keys[0]).update_attributes!(users_attributes.values[0])

      users_attributes.each do |id, attributes|
        user = User.find(id)
        email = attributes[:email] || attributes[:email_address]
        password = attributes[:password] || attributes[:encrypted_password]

        assert_equal attributes[:name], user.name
        assert_equal email, user.email
        assert_equal password, user.password
      end

      # Migrate to add mirror
      ActiveRecord::Migrator.migrate(MIGRATION_PATH, MIGRATION_CREATE_MIRROR_COLUMN_VERSION)
      User.reset_column_information

      users_attributes[users_attributes.keys[1]] = {:name => "step_1", :email => "step_1@email.com", :password => "step_1_password"}
      User.find(users_attributes.keys[1]).update_attributes!(users_attributes.values[1])

      users_attributes[users_attributes.keys[2]] = {:name => "step_2", :email_address => "step_2@email.com", :encrypted_password => "step_2_password"}
      User.find(users_attributes.keys[2]).update_attributes!(users_attributes.values[2])

      users_attributes.each do |id, attributes|
        user = User.find(id)
        email = attributes[:email] || attributes[:email_address]
        password = attributes[:password] || attributes[:encrypted_password]

        assert_equal attributes[:name], user.name
        assert_equal email, user.email
        assert_equal email, user.email_address
        assert_equal password, user.password
        assert_equal password, user.encrypted_password
      end

      # Migrate to remove mirror
      ActiveRecord::Migrator.migrate(MIGRATION_PATH, MIGRATION_REMOVE_MIRROR_COLUMN_VERSION)
      User.reset_column_information

      users_attributes[users_attributes.keys[3]] = {:name => "step_3", :email_address => "step_3@email.com", :encrypted_password => "step_3_password"}
      User.find(users_attributes.keys[3]).update_attributes!(users_attributes.values[3])

      users_attributes.each do |id, attributes|
        user = User.find(id)
        email = attributes[:email] || attributes[:email_address]
        password = attributes[:password] || attributes[:encrypted_password]

        assert_equal attributes[:name], user.name
        assert_equal email, user.email_address
        assert_equal password, user.encrypted_password
      end

      # Rollback to add mirror
      ActiveRecord::Migrator.migrate(MIGRATION_PATH, MIGRATION_CREATE_MIRROR_COLUMN_VERSION)
      User.reset_column_information

      users_attributes[users_attributes.keys[4]] = {:name => "step_4", :email => "step_4@email.com", :password => "step_4_password"}
      User.find(users_attributes.keys[4]).update_attributes!(users_attributes.values[4])

      users_attributes.values[users_attributes.keys[5]] = {:name => "step_5", :email_address => "step_5@email.com", :encrypted_password => "step_5_password"}
      User.find(users_attributes.keys[5]).update_attributes!(users_attributes.values[5])

      users_attributes.each do |id, attributes|
        user = User.find(id)
        email = attributes[:email] || attributes[:email_address]
        password = attributes[:password] || attributes[:encrypted_password]

        assert_equal attributes[:name], user.name
        assert_equal email, user.email
        assert_equal email, user.email_address
        assert_equal password, user.password
        assert_equal password, user.encrypted_password
      end

      # Rollback to create tables
      ActiveRecord::Migrator.migrate(MIGRATION_PATH, MIGRATION_CREATE_USER_VERSION)
      User.reset_column_information

      users_attributes.values[users_attributes.keys[6]] = {:name => "step_6", :email => "step_6@email.com", :password => "step_6_password"}
      User.find(users_attributes.keys[6]).update_attributes!(users_attributes.values[6])

      users_attributes.each do |id, attributes|
        user = User.find(id)
        email = attributes[:email] || attributes[:email_address]
        password = attributes[:password] || attributes[:encrypted_password]

        assert_equal attributes[:name], user.name
        assert_equal email, user.email
        assert_equal password, user.password
      end

      # Migrate to add mirror
      ActiveRecord::Migrator.migrate(MIGRATION_PATH, MIGRATION_CREATE_MIRROR_COLUMN_VERSION)
      User.reset_column_information

      users_attributes[users_attributes.keys[7]] = {:name => "step_7", :email => "step_7@email.com", :password => "step_7_password"}
      User.find(users_attributes.keys[7]).update_attributes!(users_attributes.values[7])

      users_attributes[users_attributes.keys[8]] = {:name => "step_8", :email_address => "step_8@email.com", :encrypted_password => "step_8_password"}
      User.find(users_attributes.keys[8]).update_attributes!(users_attributes.values[8])

      users_attributes.each do |id, attributes|
        user = User.find(id)
        email = attributes[:email] || attributes[:email_address]
        password = attributes[:password] || attributes[:encrypted_password]

        assert_equal attributes[:name], user.name
        assert_equal email, user.email
        assert_equal email, user.email_address
        assert_equal password, user.password
        assert_equal password, user.encrypted_password
      end
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
    db_name = 'no_downtime_migrations_gem_test'
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
