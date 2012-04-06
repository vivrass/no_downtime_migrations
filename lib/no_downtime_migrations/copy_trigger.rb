module ActiveRecord
  module CopyTrigger
    def create_copy_column(table, source_column, destination_column)
      # Trigger insert
      create_trigger(copy_column_trigger_name(table, source_column, destination_column, :insert)).on(table).before(:insert)  do
        sql = <<-SQL
          IF #{sql_not_blank("NEW.#{source_column}")} THEN
            SET NEW.#{destination_column} = NEW.#{source_column};
          END IF;
          IF #{sql_not_blank("NEW.#{destination_column}")} THEN
            SET NEW.#{source_column} = NEW.#{destination_column};
          END IF;
        SQL
      end

      # Trigger update
      create_trigger(copy_column_trigger_name(table, source_column, destination_column, :update)).on(table).before(:update)  do
        sql = <<-SQL
          IF NEW.#{source_column} != OLD.#{source_column} AND #{sql_not_blank("NEW.#{source_column}")} THEN
            SET NEW.#{destination_column} = NEW.#{source_column};
          END IF;
          IF NEW.#{destination_column} != OLD.#{destination_column} AND #{sql_not_blank("NEW.#{destination_column}")} THEN
            SET NEW.#{source_column} = NEW.#{destination_column};
          END IF;
        SQL
      end

      # Copy old column in new one
      execute "UPDATE #{table} SET #{destination_column} = #{source_column}"
    end

    def remove_copy_column(table, source_column, destination_column)
      [:insert, :update].each do |sql_method|
        drop_trigger copy_column_trigger_name(table, source_column, destination_column, sql_method), table
      end
    end

    protected
    def copy_column_trigger_name(table, source_column, destination_column, sql_method)
      name = "#{table}_copy_column_#{source_column}_#{destination_column}_on_#{sql_method}"
      if name.size > 63
        name = "copy_column_#{sql_method}_#{Digest::SHA1.hexdigest(source_column.to_s + destination_column.to_s)}"
      end

      name
    end

    def sql_not_blank(column_name)
      "#{column_name} IS NOT NULL AND #{column_name} != ''"
    end
  end
end

ActiveRecord::ConnectionAdapters::AbstractAdapter.class_eval { include ActiveRecord::CopyTrigger }
