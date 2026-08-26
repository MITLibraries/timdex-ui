# frozen_string_literal: true

# MergedSearchPaginator encapsulates stateless merged pagination logic for combining
# two API result sets.
class MergedSearchPaginator
  attr_reader :primo_total, :timdex_total, :current_page, :per_page

  def initialize(primo_total:, timdex_total:, current_page:, per_page:)
    @primo_total = primo_total
    @timdex_total = timdex_total
    @current_page = current_page
    @per_page = per_page
  end

  # Returns an array of :primo and :timdex symbols for the merged result order on this page.
  def merge_plan
    total_results = primo_total + timdex_total
    start_index = (current_page - 1) * per_page
    end_index = [start_index + per_page, total_results].min
    plan = []
    primo_used = 0
    timdex_used = 0
    i = 0
    while i < end_index
      if primo_used < primo_total && (timdex_used >= timdex_total || primo_used <= timdex_used)
        source = :primo
        primo_used += 1
      elsif timdex_used < timdex_total
        source = :timdex
        timdex_used += 1
      end
      plan << source if i >= start_index
      i += 1
    end
    plan
  end

  # Returns [primo_offset, timdex_offset] for the start of this page. If a source
  # is exhausted, that source offset is nil so callers can skip the API call.
  def api_offsets
    start_index = (current_page - 1) * per_page
    primo_offset = 0
    timdex_offset = 0
    i = 0
    while i < start_index
      if primo_offset < primo_total && (timdex_offset >= timdex_total || primo_offset <= timdex_offset)
        primo_offset += 1
      elsif timdex_offset < timdex_total
        timdex_offset += 1
      else
        break
      end
      i += 1
    end

    primo_offset = nil if primo_offset >= primo_total
    timdex_offset = nil if timdex_offset >= timdex_total

    [primo_offset, timdex_offset]
  end
end
