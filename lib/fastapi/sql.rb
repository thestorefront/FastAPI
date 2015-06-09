require 'forwardable'

module FastAPI
  class SQL
    extend Forwardable

    def_delegator :@sql, :[]

    def initialize(filters, offset, count, klazz, whitelist, safe = false)

      results = filter_fields(klazz, whitelist)
      models, belongs, has_many, fields = results.values_at(:models, :belongs, :has_many, :fields)

      model_name = klazz.to_s.tableize.singularize
      table_name = klazz.to_s.tableize

      # Base fields
      field_list = generate_field_list(klazz, fields, table_name)

      # Belongs fields
      joins = parse_belongs(belongs, field_list, table_name)

      # Many fields (1 to many)
      parse_manys(has_many, filters, field_list, model_name, table_name)

      filter_string = filters[:main].size > 0 ? "WHERE #{filters[:main].join(' AND ')}" : nil
      order_string  = filters[:main_order] ? "ORDER BY #{filters[:main_order]}" : nil

      @sql = {
        query: [
          "SELECT #{field_list.join(', ')}",
          "FROM #{table_name}",
          joins.join(' '),
          filter_string,
          order_string,
          "LIMIT #{count}",
          "OFFSET #{offset}"
        ].compact.join(' '),
        count_query: [
          "SELECT COUNT(id) FROM #{table_name}",
          filter_string
        ].compact.join(' '),
        models: models
      }
    end

    private
    def filter_fields(klazz, whitelist)
      skeleton = { models: {}, belongs: [], has_many: [], fields: [] }
      (klazz.fastapi_fields + whitelist).each_with_object(skeleton) do |field, results|

        if klazz.reflect_on_all_associations(:belongs_to).map(&:name).include?(field)

          class_name = klazz.reflect_on_association(field).options[:class_name]
          model      = constantize_model(class_name, field)

          results[:models][field] = model
          results[:belongs] << { model: model, alias: field, type: :belongs_to }

        elsif klazz.reflect_on_all_associations(:has_one).map(&:name).include?(field)

          class_name = klazz.reflect_on_association(field).options[:class_name]
          model      = constantize_model(class_name, field)

          results[:models][field] = model
          results[:belongs] << { model: model, alias: field, type: :has_one }

        elsif klazz.reflect_on_all_associations(:has_many).map(&:name).include?(field)

          model = field.to_s.singularize.classify.constantize

          results[:models][field] = model
          results[:has_many] << model

        elsif klazz.column_names.include?(field.to_s)
          results[:fields] << field
        end

      end
    end

    def generate_field_list(klazz, fields, table)
      fields.each_with_object([]) do |field, list|
        if klazz.columns_hash[field.to_s].respond_to?(:array) && klazz.columns_hash[field.to_s].array
          list << "ARRAY_TO_JSON(#{table}.#{field}) AS #{field}"
        else
          list << "#{table}.#{field} AS #{field}"
        end
      end
    end

    def parse_belongs(belongs, field_list, model_table_name)
      belongs.each_with_object([]) do |model_data, join_list|

        table_name  = model_data[:model].to_s.tableize
        table_alias = model_data[:alias].to_s.pluralize

        field_name          = model_data[:alias].to_s
        singular_table_name = model_table_name.singularize

        model_data[:model].fastapi_fields_sub.each do |field|
          if model_data[:model].columns_hash[field.to_s].respond_to?(:array) && model_data[:model].columns_hash[field.to_s].array
            field_list << "ARRAY_TO_JSON(#{table_alias}.#{field}) AS #{field_name}__#{field}"
          else
            field_list << "#{table_alias}.#{field} AS #{field_name}__#{field}"
          end
        end

        # fields
        if model_data[:type] == :belongs_to
          # joins
          join_list << "LEFT JOIN #{table_name} AS #{table_alias} " \
                       "ON #{table_alias}.id = #{model_table_name}.#{field_name}_id"
        elsif model_data[:type] == :has_one
          join_list << "LEFT JOIN #{table_name} AS #{table_alias} " \
                       "ON #{table_alias}.#{singular_table_name}_id = #{model_table_name}.id"
        end
      end
    end

    def parse_manys(has_many, filters, field_list, model_name, table_name)
      has_many.each do |model|

        model_string_table = model.to_s.tableize
        model_symbol = model_string_table.to_sym

        model_fields = model.fastapi_fields_sub.each_with_object([]) do |field, m_fields|
          m_fields << "__#{model_string_table}.#{field}"
        end

        if filters[:has_many].has_key?(model_symbol)

          if not filters[:has_many][model_symbol].blank?
            has_many_filters = "AND #{filters[:has_many][model_symbol].join(' AND ')}"
          else
            has_many_filters = nil
          end

          if not filters[:has_many_order][model_symbol].blank?
            has_many_order = "ORDER BY #{filters[:has_many_order][model_symbol]}"
          else
            has_many_order = nil
          end

        end

        field_list << [
          "ARRAY_TO_JSON(ARRAY(SELECT ROW(#{model_fields.join(', ')})",
          "FROM #{model_string_table}",
          "AS __#{model_string_table}",
          "WHERE __#{model_string_table}.#{model_name}_id IS NOT NULL",
          "AND __#{model_string_table}.#{model_name}_id",
          "= #{table_name}.id",
          has_many_filters,
          has_many_order,
          ")) AS __many__#{model_string_table}"
        ].compact.join(' ')

      end
    end

    def constantize_model(class_name, field)
      (class_name ? class_name : field.to_s.classify).constantize
    end
  end
end
