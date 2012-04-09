require 'test_helper'
require 'ruby_debug'

class PerformanceTest < ActionDispatch::IntegrationTest
  MIGRATION_PATH = "db/migrate"
  MIGRATION_CREATE_USER_VERSION          = 1;
  MIGRATION_CREATE_MIRROR_COLUMN_VERSION = 2;
  MIGRATION_REMOVE_MIRROR_COLUMN_VERSION = 3;

  SERVER_PORT = 7171


  context "Resetted database to version 1" do
    setup do
      ActiveRecord::Migrator.migrate(MIGRATION_PATH, MIGRATION_CREATE_USER_VERSION)
      User.reset_column_information
      Capybara.current_driver = Capybara.javascript_driver
    end

    context 'Verify performance at each step' do
      should "READ" do
        execution_time = Benchmark.measure do
          create_users
        end
        puts "Create users : #{execution_time}"

        puts "#{"#"*80}\n# READ\n#{"#"*80}"
        visit("/") # Start the server

        puts "Initial"
        puts ApacheBenchmark.new.test

        puts "\nMigration"
        execution_time = Benchmark.measure do
          ActiveRecord::Migrator.migrate(MIGRATION_PATH, MIGRATION_CREATE_MIRROR_COLUMN_VERSION)
        end
        puts "Total migration time : #{execution_time}"

        puts "\nExecution"
        puts ApacheBenchmark.new.test

        puts "\nRollback migration"
        execution_time = Benchmark.measure do
          ActiveRecord::Migrator.migrate(MIGRATION_PATH, MIGRATION_REMOVE_MIRROR_COLUMN_VERSION)
        end
        puts "Total migration time : #{execution_time}"
      end

      should "WRITE" do
        puts "#{"#"*80}\n# WRITE\n#{"#"*80}"
        TEST_COUNT = 10000

        puts "Initial"
        execution_time = Benchmark.measure do
          TEST_COUNT.times do |i|
            User.create(:name => "name #{i}", :email => "email_#{1}@email.com", :password => "psw_#{i}")
          end
        end
        puts "Insert #{TEST_COUNT} users : #{execution_time}"

        ActiveRecord::Migrator.migrate(MIGRATION_PATH, MIGRATION_CREATE_MIRROR_COLUMN_VERSION)
        User.reset_column_information

        puts "Execution old columns"
        execution_time = Benchmark.measure do
          TEST_COUNT.times do |i|
            User.create(:name => "name #{i}", :email => "email_#{1}@email.com", :password => "psw_#{i}")
          end
        end
        puts "Insert #{TEST_COUNT} users : #{execution_time}"

        puts "Execution new columns"
        execution_time = Benchmark.measure do
          TEST_COUNT.times do |i|
            # password => can't specify it to NULL if defined in query
            User.create(:name => "name #{i}", :email_address => "email_#{1}@email.com", :encrypted_password => "psw_#{i}", :password => "")
          end
        end
        puts "Insert #{TEST_COUNT} users : #{execution_time}"

        ActiveRecord::Migrator.migrate(MIGRATION_PATH, MIGRATION_REMOVE_MIRROR_COLUMN_VERSION)
        User.reset_column_information

        puts "After"
        execution_time = Benchmark.measure do
          TEST_COUNT.times do |i|
            User.create(:name => "name #{i}", :email_address => "email_#{1}@email.com", :encrypted_password => "psw_#{i}")
          end
        end
        puts "Insert #{TEST_COUNT} users : #{execution_time}"
      end
    end
  end

private
  def create_users(count=100000)
    sql_values = []
    missing = count - User.count
    if missing > 0
      missing.times do |i|
        sql_values << "('#{i}', '#{i}@email', 'psw_#{i}')"
      end

      ActiveRecord::Base.connection.execute("INSERT INTO users (name, email, password) VALUES #{sql_values.join(",")};") unless sql_values.empty?
    end
  end
end

class ApacheBenchmark
  def initialize(host="#{Capybara.app_host}/", total_request=100, simultaneous_request=5)
    @host = host
    @total_request = total_request
    @simultaneous_request = simultaneous_request
  end

  def test
    output = ""
    @execution_time = Benchmark.measure do
      command = "ab -n #{@total_request} -c #{@simultaneous_request} #{@host}/"
      output = `#{command}`
    end

    parse_output(output)
  end

  def parse_output(output)
    @output = output
  end

  def to_s
    puts "Execution time : #{@execution_time}"
    puts "Output :\n#{@output}"
  end
end
