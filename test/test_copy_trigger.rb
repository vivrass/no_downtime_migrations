require 'helper'

class NullConnection
end

class MockAdapter < ActiveRecord::ConnectionAdapters::AbstractAdapter
  def adapter_name
    "mysql"
  end
end

class TestCopyTrigger < Test::Unit::TestCase
  context "given a MySQL adapter" do
    setup do
      @connection = NullConnection
      @adapter = MockAdapter.new(@connection)
    end

    context "#create_copy_column" do
      should "execute a copy of the first column into the second" do
        found = 0
        @adapter.expects(:execute).at_least_once.with do |sql_query|
          if sql_query == "UPDATE table_name SET second_column = first_column"
            found += 1
          end
          true
        end

        @adapter.create_copy_column("table_name", "first_column", "second_column")
        assert_equal 1, found
      end

      [:insert, :update].each do |sql_method|
        context "sql #{sql_method}" do
          should "execute a old trigger drop" do
            expected_sql = "DROP TRIGGER IF EXISTS table_name_copy_column_first_column_second_column_on_#{sql_method};"
            assert_expects_params @adapter, :execute, expected_sql
          end

          should "execute create the trigger" do
            found = 0
            expected_sql = <<-SQL
              CREATE TRIGGER 
                table_name_copy_column_first_column_second_column_on_#{sql_method}
              AFTER #{sql_method} ON
                table_name
              FOR EACH ROW
              BEGIN
                UPDATE table_name SET second_column = first_column;
              END
            SQL

            assert_expects_params @adapter, :execute, expected_sql
          end
        end
      end
    end
  end

  private
  def assert_expects_params(object, function_name, params, count=1)
    all_params = []
    found = 0

    expected_params = params.gsub(/\s+/, " ").strip.downcase
    object.expects(function_name).at_least_once.with do |fct_params|
      received_params = fct_params.gsub(/\s+/, " ").strip.downcase

      all_params << received_params
      if received_params == expected_params
        found += 1
      end
      true
    end

    @adapter.create_copy_column("table_name", "first_column", "second_column")
    assert_equal count, found, "Expected :\n#{expected_params}\nReceived :\n#{all_params.join("\n")}"
  end
end
