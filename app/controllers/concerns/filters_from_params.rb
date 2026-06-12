module FiltersFromParams
  extend ActiveSupport::Concern

  private

  # Apply f[column][op]=value URL params to an ActiveRecord scope.
  # The scope's model must `include Filterable`.
  def apply_url_filters(scope)
    model = scope.model
    return scope unless model.respond_to?(:apply_filters) && params[:f].present?

    f_hash = params[:f].respond_to?(:to_unsafe_h) ? params[:f].to_unsafe_h : params[:f]
    model.apply_filters(scope, f_hash)
  end

  # Apply sort/dir params using a sort_key → column mapping.
  # sort_map values can be:
  #   - Symbol: column name (e.g., :name)
  #   - String: raw SQL expression (e.g., "COALESCE(total_spend, '')")
  def apply_url_sorting(scope, sort_map, default_sort: nil, default_dir: :asc)
    sort_key = params[:sort].presence || default_sort
    dir_param = params[:dir].presence || default_dir.to_s
    dir = dir_param == "desc" ? "DESC" : "ASC"
    return scope unless sort_key && sort_map.key?(sort_key)

    clause = sort_map[sort_key]
    if clause.is_a?(Symbol)
      scope.order(clause => dir.downcase.to_sym)
    else
      scope.order(Arel.sql("#{clause} #{dir}"))
    end
  end
end
