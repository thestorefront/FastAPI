require 'forwardable'

module FastAPI
  class SQL
    extend Forwardable

    def_delegator :@sql, :[]

    def initialize(filters, offset, count, klazz, whitelist)

      results = filter_fields(klazz, whitelist)
      models, belongs, has_many, fields = results.values_at(:models, :belongs, :has_many, :fields)

      # Base fields
      field_list = generate_field_list(klazz, fields)

      # Belongs fields
      joins = parse_belongs(belongs, field_list, klazz)

      # Many fields (1 to many)
      parse_manys(has_many, filters, field_list, klazz)

      filter_string = filters[:main].size > 0 ? "WHERE #{filters[:main].join(' AND ')}" : nil
      order_string  = filters[:main_order] ? "ORDER BY #{filters[:main_order]}" : nil

      primary_key = klazz.primary_key
      table_name  = klazz.table_name

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
          "SELECT COUNT(#{primary_key}) FROM #{table_name}",
          filter_string
        ].compact.join(' '),
        models: models
      }
    end

    private

    def filter_fields(klazz, whitelist)
      skeleton = { models: {}, belongs: [], has_many: [], fields: [] }
      (klazz.fastapi_fields + whitelist).each_with_object(skeleton) do |field, results|

        association = klazz.reflect_on_association(field)

        if association.present?
          model = association.klass
          results[:models][association.name] = model
        end

        if association.is_a?(ActiveRecord::Reflection::BelongsToReflection)
          results[:belongs] << { model: model, association: association, type: :belongs_to }

        elsif association.is_a?(ActiveRecord::Reflection::HasOneReflection)
          results[:belongs] << { model: model, association: association, type: :has_one }

        elsif association.is_a?(ActiveRecord::Reflection::HasManyReflection)
          results[:has_many] << { model: model, association: association, type: :has_many }

        elsif klazz.column_names.include?(field.to_s)
          results[:fields] << field
        end
      end
    end

    def generate_field_list(klazz, fields)
      fields.each_with_object([]) do |field, list|
        if klazz.columns_hash[field.to_s].respond_to?(:array) && klazz.columns_hash[field.to_s].array
          list << %(ARRAY_TO_JSON("#{klazz.table_name}"."#{field}") AS "#{field}")
        else
          list << %("#{klazz.table_name}"."#{field}" AS "#{field}")
        end
      end
    end

    def parse_belongs(belongs, field_list, parent_model)
      belongs.each_with_object([]) do |model_data, join_list|

        model       = model_data[:model]
        table_name  = model.table_name
        primary_key = model.primary_key

        association      = model_data[:association]
        association_name = association.name
        foreign_key      = association.foreign_key

        parent_table_name = parent_model.table_name
        parent_primary_key = parent_model.primary_key

        model_data[:model].fastapi_fields_sub.each do |field|
          if model_data[:model].columns_hash[field.to_s].respond_to?(:array) && model_data[:model].columns_hash[field.to_s].array
            field_list << %(ARRAY_TO_JSON("#{association_name}"."#{field}") AS "#{association_name}__#{field}")
          else
            field_list << %("#{association_name}"."#{field}" AS "#{association_name}__#{field}")
          end
        end

        # fields
        if model_data[:type] == :belongs_to

          # joins
          join_list << %(LEFT JOIN "#{table_name}" AS "#{association_name}" ON "#{parent_table_name}"."#{foreign_key}" = "#{association_name}"."#{primary_key}")
        elsif model_data[:type] == :has_one
          join_list << %(LEFT JOIN "#{table_name}" AS "#{association_name}" ON "#{association_name}"."#{foreign_key}" = "#{parent_table_name}"."#{parent_primary_key}")
        end
      end
    end

    def parse_manys(has_many, filters, field_list, parent_model)
      has_many.each do |model_data|

        model       = model_data[:model]
        table_name  = model.table_name

        association      = model_data[:association]
        association_name = association.name
        foreign_key      = association.foreign_key

        parent_table_name  = parent_model.table_name
        parent_primary_key = parent_model.primary_key

        model_symbol = table_name.to_sym

        model_fields = model.fastapi_fields_sub.each_with_object([]) do |field, m_fields|
          m_fields << %("__#{association_name}"."#{field}")
        end

        if filters[:has_many].key?(model_symbol)

          if filters[:has_many][model_symbol].present?
            has_many_filters = %(AND #{filters[:has_many][model_symbol].join(' AND ')})
          else
            has_many_filters = nil
          end

          if filters[:has_many_order][model_symbol].present?
            has_many_order = %(ORDER BY #{filters[:has_many_order][model_symbol]})
          else
            has_many_order = nil
          end
        end

        field_list << [
          %[ARRAY_TO_JSON(ARRAY(SELECT ROW(#{model_fields.join(', ')})],
          %[FROM "#{table_name}"],
          %[AS "__#{association_name}"],
          %[WHERE "__#{association_name}"."#{foreign_key}" IS NOT NULL],
          %[AND "__#{association_name}"."#{foreign_key}"],
          %[= "#{parent_table_name}"."#{parent_primary_key}"],
          has_many_filters,
          has_many_order,
          %[)) AS "__many__#{association_name}"]
        ].compact.join(' ')
      end
    end
  end
end
