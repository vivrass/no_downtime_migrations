module ActiveRecord
  module CopyColumn
    def create_copy_column(table, columns)
      raise ArgumentError.new("columns need to be a Hash, got #{columns.class}") if Hash === columns.class

      # Trigger insert
      create_trigger(copy_column_trigger_name(table, columns, :insert)).on(table).before(:insert)  do
        sql = ""
        columns.each do |source_column, destination_column|
          sql += <<-SQL
            IF #{sql_not_blank("NEW.#{source_column}")} THEN
              SET NEW.#{destination_column} = NEW.#{source_column};
            END IF;
            IF #{sql_not_blank("NEW.#{destination_column}")} THEN
              SET NEW.#{source_column} = NEW.#{destination_column};
            END IF;
          SQL
        end

        sql
      end

      # Trigger update
      create_trigger(copy_column_trigger_name(table, columns, :update)).on(table).before(:update)  do
        sql = ""
        columns.each do |source_column, destination_column|
          sql += <<-SQL
            IF #{sql_update_condition(source_column)} THEN
              SET NEW.#{destination_column} = NEW.#{source_column};
            ELSEIF #{sql_update_condition(destination_column)} THEN
              SET NEW.#{source_column} = NEW.#{destination_column};
            END IF;
          SQL
        end

        sql
      end

      # Copy old column in new one
      update_conditions = []
      columns.each do |source_column, destination_column|
        update_conditions << "#{destination_column} = #{source_column}"
      end
      execute "UPDATE #{table} SET #{update_conditions.join(", ")}"
    end

    def remove_copy_column(table, columns)
      raise ArgumentError.new("columns need to be a Hash, got #{columns.class}") if Hash === columns.class

      [:insert, :update].each do |sql_method|
        drop_trigger copy_column_trigger_name(table, columns, sql_method), table
      end
    end

    protected
    def copy_column_trigger_name(table, columns, sql_method)
      name = if columns.size == 1
               "#{table}_copy_column_#{columns.keys.first}_#{columns.values.first}_on_#{sql_method}"
             else
               "#{table}_copy_multiple_columns_on_#{sql_method}"
             end
      if name.size > 63
        name = "copy_column_#{sql_method}_#{Digest::SHA1.hexdigest(columns.map{|k,v| "#{k} => #{v}"}.join(", "))}"
      end

      name
    end

    def sql_not_blank(column_name)
      "#{column_name} IS NOT NULL AND #{column_name} != ''"
    end

    def sql_update_condition(column_name)
      "NEW.#{column_name} != OLD.#{column_name} OR (NEW.#{column_name} IS NOT NULL AND OLD.#{column_name} IS NULL) OR (NEW.#{column_name} IS NULL AND OLD.#{column_name} IS NOT NULL)"
    end
  end
end

ActiveRecord::ConnectionAdapters::AbstractAdapter.class_eval { include ActiveRecord::CopyColumn }
