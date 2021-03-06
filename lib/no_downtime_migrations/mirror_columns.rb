module ActiveRecord
  module MirrorColumns
    # Create the mirror between the columns
    # table : SQL table on which the mirror will be defined
    # columns : Hash of the columns of the form {old_column_name_1 => new_column_name_1, old_column_name_2 => new_column_name_2}
    def add_mirror_columns(table, columns)
      raise ArgumentError.new("columns need to be a Hash, got #{columns.class}") unless columns.is_a?(Hash)

      # Trigger insert
      create_trigger(mirror_columns_trigger_name(table, columns, :insert)).on(table).before(:insert)  do
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
      create_trigger(mirror_columns_trigger_name(table, columns, :update)).on(table).before(:update)  do
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

    # Remove the mirror between the columns
    # table : SQL table on which the mirror will be defined
    # columns : Hash of the columns of the form {old_column_name_1 => new_column_name_1, old_column_name_2 => new_column_name_2}
    def remove_mirror_columns(table, columns)
      raise ArgumentError.new("columns need to be a Hash, got #{columns.class}") unless columns.is_a?(Hash)

      [:insert, :update].each do |sql_method|
        drop_trigger mirror_columns_trigger_name(table, columns, sql_method), table
      end
    end

    protected
    # Generate the more precise name for the trigger without conflicts between sql methods
    # Note : MySQL limit only one after/before #{sql_method) per table
    def mirror_columns_trigger_name(table, columns, sql_method)
      column_names = (columns.keys + columns.values).map(&:to_s).sort
      name = if column_names.size == 2
               "#{table}_mirror_columns_#{column_names.first}_#{column_names.second}_on_#{sql_method}"
             else
               "#{table}_mirror_multiple_columns_on_#{sql_method}"
             end
      # postgreSQL limitation enforced by hair_trigger
      if name.size > 63
        name = "mirror_columns_#{sql_method}_#{Digest::SHA1.hexdigest(column_names.join(", "))}"
      end

      name
    end

    def sql_not_blank(column_name)
      "#{column_name} IS NOT NULL AND #{column_name} != ''"
    end

    def sql_update_condition(column_name)
      # 1. new != old
      # 2. new != nil and old = nil
      # 3. new =  nil and old != nil
      "NEW.#{column_name} != OLD.#{column_name} OR (NEW.#{column_name} IS NOT NULL AND OLD.#{column_name} IS NULL) OR (NEW.#{column_name} IS NULL AND OLD.#{column_name} IS NOT NULL)"
    end
  end
end

ActiveRecord::ConnectionAdapters::AbstractAdapter.class_eval { include ActiveRecord::MirrorColumns }
