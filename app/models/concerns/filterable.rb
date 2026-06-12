module Filterable
  extend ActiveSupport::Concern

  OPERATORS = {
    enum: %w[eq neq in not_in],
    number: %w[eq gte lte between],
    text: %w[contains starts_with eq is_empty is_not_empty],
    date: %w[gte lte is_empty is_not_empty]
  }.freeze

  included do
    class_attribute :filter_columns, default: {}
  end

  class_methods do
    def filterable(key, type:, label: nil, column: nil)
      self.filter_columns = filter_columns.merge(
        key.to_s => {
          type: type.to_sym,
          label: label || key.to_s.humanize,
          column: (column || key).to_s
        }
      )
    end

    def apply_filters(relation, filter_params)
      raw = normalize_filter_params(filter_params)
      return relation if raw.blank?

      raw.each do |key, ops|
        col_config = filter_columns[key.to_s]
        next unless col_config
        next unless ops.respond_to?(:each)

        ops.each do |op, value|
          next unless OPERATORS[col_config[:type]]&.include?(op.to_s)
          relation = apply_filter_op(relation, col_config[:column], op.to_s, value.to_s, col_config[:type])
        end
      end

      relation
    end

    def active_filters_from(filter_params)
      raw = normalize_filter_params(filter_params)
      return [] if raw.blank?

      filters = []
      raw.each do |key, ops|
        col_config = filter_columns[key.to_s]
        next unless col_config
        next unless ops.respond_to?(:each)

        ops.each do |op, value|
          next unless OPERATORS[col_config[:type]]&.include?(op.to_s)
          next if value.blank? && !%w[is_empty is_not_empty].include?(op.to_s)

          filters << {
            key: key.to_s,
            column: col_config[:column],
            op: op.to_s,
            value: value.to_s,
            label: col_config[:label],
            type: col_config[:type]
          }
        end
      end
      filters
    end

    private

    def normalize_filter_params(filter_params)
      params = filter_params || {}
      params = params.to_unsafe_h if params.respond_to?(:to_unsafe_h)
      params
    end

    def apply_filter_op(rel, col, op, val, col_type = nil)
      col_sql = "#{rel.connection.quote_table_name(rel.table_name)}.#{rel.connection.quote_column_name(col)}"
      type = rel.model.type_for_attribute(col)
      cast = ->(v) { type.cast(v) }

      # Date filters cast through Date.parse and no-op (rather than match nothing
      # or 500) on unparseable input; empty means NULL only (a date column has no
      # "" sentinel like the string-oriented is_empty/is_not_empty branches below).
      if col_type == :date
        case op
        when "gte", "lte"
          date = parse_filter_date(val)
          return rel if date.nil?
          return op == "gte" ? rel.where("#{col_sql} >= ?", date) : rel.where("#{col_sql} <= ?", date)
        when "is_empty"     then return rel.where(col => nil)
        when "is_not_empty" then return rel.where.not(col => nil)
        end
      end

      case op
      when "eq"       then rel.where(col => cast.call(val))
      when "neq"      then rel.where.not(col => cast.call(val))
      when "in"
        values = val.split(",").map(&:strip).reject(&:blank?).map(&cast)
        values.empty? ? rel : rel.where(col => values)
      when "not_in"
        values = val.split(",").map(&:strip).reject(&:blank?).map(&cast)
        values.empty? ? rel : rel.where.not(col => values)
      when "gte"      then rel.where("#{col_sql} >= ?", cast.call(val))
      when "lte"      then rel.where("#{col_sql} <= ?", cast.call(val))
      when "between"
        min, max = val.split("..", 2)
        (min.blank? || max.blank?) ? rel : rel.where(col => cast.call(min)..cast.call(max))
      when "contains"    then rel.where("#{col_sql} LIKE ?", "%#{sanitize_like(val)}%")
      when "starts_with" then rel.where("#{col_sql} LIKE ?", "#{sanitize_like(val)}%")
      when "is_empty"    then rel.where(col => [nil, ""])
      when "is_not_empty" then rel.where.not(col => [nil, ""])
      else rel
      end
    end

    def sanitize_like(str)
      str.to_s.gsub("%", "\\%").gsub("_", "\\_")
    end

    # Parse a date filter value (ISO-8601 preferred), returning nil on anything
    # unparseable so the caller can no-op instead of raising or matching nothing.
    def parse_filter_date(val)
      str = val.to_s.strip
      return nil if str.blank?

      Date.iso8601(str)
    rescue ArgumentError
      begin
        Date.parse(str)
      rescue ArgumentError, TypeError
        nil
      end
    end
  end
end
