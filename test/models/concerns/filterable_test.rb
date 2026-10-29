require "test_helper"

# Exercises the Filterable concern in isolation against a throwaway table so the
# test does not depend on any application model. Covers every operator across the
# :text, :enum, :number, and :date types, plus active_filters_from. The :date
# coverage (gte/lte ranges, NULL is_empty/is_not_empty, no-op on unparseable
# input) is ported from taphealth-pipeline, the canonical copy of this concern.
class FilterableTest < ActiveSupport::TestCase
  # A bare ApplicationRecord that includes Filterable and is backed by an
  # in-test temp table, so the concern can be exercised without app models.
  class Widget < ApplicationRecord
    self.table_name = "filterable_test_widgets"
    include Filterable

    filterable :name,     type: :text,   label: "Name"
    filterable :category, type: :enum,   label: "Category"
    filterable :price,    type: :number, label: "Price"
    filterable :due_on,   type: :date,   label: "Due"
  end

  setup do
    conn = ActiveRecord::Base.connection
    conn.create_table :filterable_test_widgets, temporary: true, force: true do |t|
      t.string  :name
      t.string  :category
      t.integer :price
      t.date    :due_on
    end
    Widget.reset_column_information

    @alpha = Widget.create!(name: "Alpha", category: "a", price: 10, due_on: Date.new(2026, 1, 15))
    @beta  = Widget.create!(name: "Beta",  category: "b", price: 20, due_on: Date.new(2026, 6, 11))
    @gamma = Widget.create!(name: "Gamma", category: "b", price: 30, due_on: Date.new(2026, 12, 31))
    @blank = Widget.create!(name: "",      category: "c", price: nil, due_on: nil)
  end

  teardown do
    ActiveRecord::Base.connection.drop_table :filterable_test_widgets, if_exists: true
  end

  def filter(column, ops)
    Widget.apply_filters(Widget.all, { column.to_s => ops }).to_a
  end

  # --- text operators ---

  test "text contains matches substrings" do
    assert_equal [ @alpha ], filter(:name, "contains" => "lph")
  end

  test "text starts_with matches prefixes only" do
    assert_equal [ @beta ], filter(:name, "starts_with" => "Bet")
  end

  test "text eq matches exact values" do
    assert_equal [ @gamma ], filter(:name, "eq" => "Gamma")
  end

  test "text is_empty matches nil and blank strings" do
    assert_equal [ @blank ], filter(:name, "is_empty" => "")
  end

  test "text is_not_empty excludes nil and blank strings" do
    assert_equal [ @alpha, @beta, @gamma ].sort_by(&:id),
                 filter(:name, "is_not_empty" => "").sort_by(&:id)
  end

  test "contains escapes LIKE wildcards in the search term" do
    # The literal "%" must not act as a wildcard, so nothing matches.
    assert_equal [], filter(:name, "contains" => "%")
  end

  # --- enum operators ---

  test "enum eq matches a single value" do
    assert_equal [ @alpha ], filter(:category, "eq" => "a")
  end

  test "enum neq excludes a value" do
    assert_equal [ @beta, @gamma, @blank ].sort_by(&:id),
                 filter(:category, "neq" => "a").sort_by(&:id)
  end

  test "enum in matches any of a comma-separated list" do
    assert_equal [ @alpha, @beta, @gamma ].sort_by(&:id),
                 filter(:category, "in" => "a,b").sort_by(&:id)
  end

  test "enum not_in excludes a comma-separated list" do
    assert_equal [ @blank ], filter(:category, "not_in" => "a,b")
  end

  test "enum in with an all-blank list is a no-op" do
    assert_equal Widget.all.to_a.sort_by(&:id),
                 filter(:category, "in" => " , ").sort_by(&:id)
  end

  # --- number operators ---

  test "number eq matches an exact value" do
    assert_equal [ @beta ], filter(:price, "eq" => "20")
  end

  test "number gte matches values at or above" do
    assert_equal [ @beta, @gamma ].sort_by(&:id),
                 filter(:price, "gte" => "20").sort_by(&:id)
  end

  test "number lte matches values at or below" do
    assert_equal [ @alpha, @beta ].sort_by(&:id),
                 filter(:price, "lte" => "20").sort_by(&:id)
  end

  test "number between matches an inclusive range" do
    assert_equal [ @beta ], filter(:price, "between" => "15..25")
  end

  test "number between with a blank bound is a no-op" do
    assert_equal Widget.all.to_a.sort_by(&:id),
                 filter(:price, "between" => "15..").sort_by(&:id)
  end

  # --- date operators (ported from taphealth-pipeline) ---

  test "date gte returns rows on or after the date" do
    assert_equal [ @beta, @gamma ].sort_by(&:id),
                 filter(:due_on, "gte" => "2026-06-11").sort_by(&:id)
  end

  test "date lte returns rows on or before the date" do
    assert_equal [ @alpha, @beta ].sort_by(&:id),
                 filter(:due_on, "lte" => "2026-06-11").sort_by(&:id)
  end

  test "date gte + lte together form a between-equivalent range" do
    assert_equal [ @beta ],
                 Widget.apply_filters(Widget.all, { "due_on" => { "gte" => "2026-02-01", "lte" => "2026-11-30" } }).to_a
  end

  test "date is_empty returns rows with NULL due_on" do
    assert_equal [ @blank ], filter(:due_on, "is_empty" => "")
  end

  test "date is_not_empty returns rows with a due_on" do
    assert_equal [ @alpha, @beta, @gamma ].sort_by(&:id),
                 filter(:due_on, "is_not_empty" => "").sort_by(&:id)
  end

  test "date gte parses non-ISO date strings via Date.parse" do
    assert_equal [ @beta, @gamma ].sort_by(&:id),
                 filter(:due_on, "gte" => "June 11, 2026").sort_by(&:id)
  end

  test "unparseable date gte input is a no-op (no rows dropped, no error)" do
    assert_equal Widget.all.to_a.sort_by(&:id),
                 filter(:due_on, "gte" => "not-a-date").sort_by(&:id)
  end

  test "unparseable date lte input is a no-op (no rows dropped, no error)" do
    assert_equal Widget.all.to_a.sort_by(&:id),
                 filter(:due_on, "lte" => "garbage").sort_by(&:id)
  end

  test "blank date gte input is a no-op" do
    assert_equal Widget.all.to_a.sort_by(&:id),
                 filter(:due_on, "gte" => "").sort_by(&:id)
  end

  # --- guards / unknown input ---

  test "unknown columns are ignored" do
    assert_equal Widget.all.to_a.sort_by(&:id),
                 Widget.apply_filters(Widget.all, { "nonexistent" => { "eq" => "x" } }).to_a.sort_by(&:id)
  end

  test "operators not valid for the column type are ignored" do
    # `contains` is a text operator; applying it to a :number column is a no-op.
    assert_equal Widget.all.to_a.sort_by(&:id),
                 filter(:price, "contains" => "2").sort_by(&:id)
  end

  test "blank filter params return the relation unchanged" do
    assert_equal Widget.all.to_a, Widget.apply_filters(Widget.all, nil).to_a
    assert_equal Widget.all.to_a, Widget.apply_filters(Widget.all, {}).to_a
  end

  # --- active_filters_from ---

  test "active_filters_from describes active filters with label/op/value/type" do
    filters = Widget.active_filters_from("name" => { "contains" => "lph" })
    assert_equal 1, filters.size
    f = filters.first
    assert_equal "name", f[:key]
    assert_equal "Name", f[:label]
    assert_equal "contains", f[:op]
    assert_equal "lph", f[:value]
    assert_equal :text, f[:type]
  end

  test "active_filters_from carries the :date type and op for date columns" do
    filters = Widget.active_filters_from("due_on" => { "gte" => "2026-06-11" })
    assert_equal 1, filters.size
    f = filters.first
    assert_equal :date, f[:type]
    assert_equal "gte", f[:op]
    assert_equal "Due", f[:label]
    assert_equal "2026-06-11", f[:value]
  end

  test "active_filters_from skips blank values except is_empty/is_not_empty" do
    assert_empty Widget.active_filters_from("name" => { "contains" => "" })
    assert_equal 1, Widget.active_filters_from("name" => { "is_empty" => "" }).size
  end

  test "active_filters_from ignores invalid operators and unknown columns" do
    assert_empty Widget.active_filters_from("price" => { "contains" => "2" })
    assert_empty Widget.active_filters_from("nope" => { "eq" => "x" })
  end

  # --- registration ---

  test "date is registered as a filter type with its operators" do
    assert_equal %w[gte lte is_empty is_not_empty], Filterable::OPERATORS[:date]
  end

  test "filterable declarations populate filter_columns" do
    config = Widget.filter_columns
    assert_equal :text,   config["name"][:type]
    assert_equal :enum,   config["category"][:type]
    assert_equal :number, config["price"][:type]
    assert_equal :date,   config["due_on"][:type]
    assert_equal "Due",   config["due_on"][:label]
  end
end
