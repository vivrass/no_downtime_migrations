module ActiveRecord
  module CopyTrigger
    def create_copy_column(table, source_column, destination_column)
      # Copy source into destination
      execute "UPDATE #{table} SET #{destination_column} = #{source_column}"

      # Triggers
      [:insert, :update].each do |sql_method|
        create_trigger(copy_column_trigger_name(table, source_column, destination_column, sql_method)).on(table).after(sql_method)  do
          "UPDATE #{table} SET #{destination_column} = #{source_column}"
        end
      end
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
  end
end

ActiveRecord::ConnectionAdapters::AbstractAdapter.class_eval { include ActiveRecord::CopyTrigger }
