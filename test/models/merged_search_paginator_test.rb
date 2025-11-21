# frozen_string_literal: true

require 'test_helper'

class MergedSearchPaginatorTest < ActiveSupport::TestCase
  test 'merge_plan handles balanced results' do
    paginator = MergedSearchPaginator.new(primo_total: 3, timdex_total: 3, current_page: 1, per_page: 6)
    assert_equal(%i[primo timdex primo timdex primo timdex], paginator.merge_plan)
  end

  test 'merge_plan handles unbalanced results' do
    paginator = MergedSearchPaginator.new(primo_total: 6, timdex_total: 2, current_page: 1, per_page: 8)
    assert_equal(%i[primo timdex primo timdex primo primo primo primo], paginator.merge_plan)
  end

  test 'api_offsets are calculated as expected' do
    paginator = MergedSearchPaginator.new(primo_total: 10, timdex_total: 10, current_page: 2, per_page: 5)
    assert_equal([3, 2], paginator.api_offsets)
  end

  test 'merge_results handles even results' do
    paginator = MergedSearchPaginator.new(primo_total: 2, timdex_total: 2, current_page: 1, per_page: 4)
    primo = %w[P1 P2]
    timdex = %w[T1 T2]
    assert_equal(%w[P1 T1 P2 T2], paginator.merge_results(primo, timdex))
  end

  test 'merge_results with shorter array' do
    paginator = MergedSearchPaginator.new(primo_total: 3, timdex_total: 1, current_page: 1, per_page: 4)
    primo = %w[P1 P2 P3]
    timdex = %w[T1]
    assert_equal(%w[P1 T1 P2 P3], paginator.merge_results(primo, timdex))
  end

  test 'api_offsets breaks when start_index exceeds totals' do
    # Use very small totals and request a page far beyond available results to exercise the break
    paginator = MergedSearchPaginator.new(primo_total: 1, timdex_total: 1, current_page: 5, per_page: 20)
    primo_offset, timdex_offset = paginator.api_offsets

    # Offsets should stop at the available totals (1 each)
    assert_equal 1, primo_offset
    assert_equal 1, timdex_offset
  end

  test 'merge_plan returns all primo when timdex is empty' do
    paginator = MergedSearchPaginator.new(primo_total: 2, timdex_total: 0, current_page: 1, per_page: 5)
    plan = paginator.merge_plan

    assert_equal %i[primo primo], plan
  end

  test 'merge_plan returns all timdex when primo is empty' do
    paginator = MergedSearchPaginator.new(primo_total: 0, timdex_total: 2, current_page: 1, per_page: 5)
    plan = paginator.merge_plan

    assert_equal %i[timdex timdex], plan
  end
end
