require 'helper'

class NullConnection
end

class MockAdapter < ActiveRecord::ConnectionAdapters::AbstractAdapter
  def adapter_name
    "mysql"
  end
end

class TestCopyColumn < Test::Unit::TestCase
  context "given an adapter" do
    setup do
      @connection = NullConnection
      @adapter = MockAdapter.new(@connection)
    end

    context "#create_copy_column" do
      should "execute a copy of the first column into the second" do
        expected_sql = "UPDATE table_name SET second_column = first_column"
        assert_expects_params @adapter, :execute, expected_sql do
          @adapter.create_copy_column("table_name", "first_column" => "second_column")
        end
      end

      context "sql insert" do
        should "execute a old trigger drop" do
          expected_sql = "DROP TRIGGER IF EXISTS table_name_copy_column_first_column_second_column_on_insert;"
          assert_expects_params @adapter, :execute, expected_sql do
            @adapter.create_copy_column("table_name", "first_column" => "second_column")
          end
        end

        should "execute create the trigger" do
          found = 0
          expected_sql = <<-SQL
            CREATE TRIGGER 
              table_name_copy_column_first_column_second_column_on_insert
            BEFORE insert ON
              table_name
            FOR EACH ROW
            BEGIN
              IF NEW.first_column IS NOT NULL AND NEW.first_column != '' THEN
                SET NEW.second_column = NEW.first_column;
              END IF;
              IF NEW.second_column IS NOT NULL AND NEW.second_column != '' THEN
                SET NEW.first_column = NEW.second_column;
              END IF;
            END
          SQL

          assert_expects_params @adapter, :execute, expected_sql do
            @adapter.create_copy_column("table_name", "first_column" => "second_column")
          end
        end
      end

      context "sql update" do
        should "execute a old trigger drop" do
          expected_sql = "DROP TRIGGER IF EXISTS table_name_copy_column_first_column_second_column_on_update;"
          assert_expects_params @adapter, :execute, expected_sql do
            @adapter.create_copy_column("table_name", "first_column" => "second_column")
          end
        end

        should "execute create the trigger" do
          found = 0
          expected_sql = <<-SQL
            CREATE TRIGGER 
              table_name_copy_column_first_column_second_column_on_update
            BEFORE update ON
              table_name
            FOR EACH ROW
            BEGIN
              IF (NEW.first_column != OLD.first_column OR OLD.first_column IS NULL) AND NEW.first_column IS NOT NULL AND NEW.first_column != '' THEN
                SET NEW.second_column = NEW.first_column;
              END IF;
              IF (NEW.second_column != OLD.second_column OR OLD.second_column IS NULL) AND NEW.second_column IS NOT NULL AND NEW.second_column != '' THEN
                SET NEW.first_column = NEW.second_column;
              END IF;
            END
          SQL

          assert_expects_params @adapter, :execute, expected_sql do
            @adapter.create_copy_column("table_name", "first_column" => "second_column")
          end
        end
      end
    end

    context "#remove_copy_column" do
      [:insert, :update].each do |sql_method|
        context "sql #{sql_method}" do
          should "execute a trigger drop" do
            expected_sql = "DROP TRIGGER IF EXISTS table_name_copy_column_first_column_second_column_on_#{sql_method};"
            assert_expects_params @adapter, :execute, expected_sql do
              @adapter.remove_copy_column("table_name", "first_column" => "second_column")
            end
          end
        end
      end
    end

    context "#copy_column_trigger_name" do
      setup do
        @table = "TABLE_NAME"
        @columns = {"FIRST_COLUMN" => "SECOND_COLUMN"}
        @sql_method = "INSERT"
      end

      should "generate the expected name" do
        expected = "TABLE_NAME_copy_column_FIRST_COLUMN_SECOND_COLUMN_on_INSERT"
        received = @adapter.send(:copy_column_trigger_name, @table, @columns, @sql_method)

        assert_equal expected, received
      end

      context "expected name > 63 characters" do
        setup do
          @columns = {"source_long_name" * 10 => "destination_long_name" * 10}
        end

        should "generate a hash for table and column names" do
          received = @adapter.send(:copy_column_trigger_name, @table, @columns, @sql_method)
          assert_match /copy_column_INSERT_\d+/, received
        end

        should "new name lenght <= 63 characters" do
          received = @adapter.send(:copy_column_trigger_name, @table, @columns, @sql_method)
          assert received.size <= 63
        end
      end

      context "multiple columns" do
        setup do
          @columns["new_src_column"] = "new_dest_column"
        end

        should "generate a name without columns in it" do
          received = @adapter.send(:copy_column_trigger_name, @table, @columns, @sql_method)
          assert_equal "TABLE_NAME_copy_multiple_columns_on_INSERT", received
        end
      end
    end

    context "#sql_not_blank" do
      should "generate the expected condition" do
        expected = "COLUMN_NAME IS NOT NULL AND COLUMN_NAME != ''"
        received = @adapter.send(:sql_not_blank, "COLUMN_NAME")

        assert_equal expected, received
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

    yield if block_given?
    assert_equal count, found, "Expected :\n#{expected_params}\nReceived :\n#{all_params.join("\n")}"
  end
end
