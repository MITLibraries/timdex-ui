require 'test_helper'

class SearchResultsLoggingTest < ActiveSupport::TestCase
  setup do
    @controller = SearchController.new
    @controller.request = ActionDispatch::TestRequest.create
    @controller.response = ActionDispatch::TestResponse.new
    @controller.stubs(:action_name).returns('results')
    @controller.instance_variable_set(:@enhanced_query, { q: 'climate' })
    @controller.instance_variable_set(:@active_tab, 'all')
    @results = [
      { api: 'primo', identifier: 'alma123' },
      { api: 'timdex', identifier: 'dspace:456' },
      { api: 'primo', identifier: nil },
      { api: 'timdex', identifier: 'alma:789' }
    ]
    @controller.instance_variable_set(:@results, @results)
  end

  test 'logs both APIs in response order without renumbering missing IDs' do
    payload = log_payload

    assert_equal 'search_results_response', payload[:event_type]
    assert_equal 1, payload[:event_version]
    assert_equal 'climate', payload[:searchterm]
    assert_equal 'success', payload[:search_outcome]
    assert_equal 'initial', payload[:response_kind]
    assert_equal 3, payload[:returned_results_count]
    assert_equal [
      { api: 'primo', record_id: 'alma123', position: 1 },
      { api: 'timdex', record_id: 'dspace:456', position: 2 },
      { api: 'timdex', record_id: 'alma:789', position: 4 }
    ], payload[:returned_results]
  end

  test 'combined Turbo response logs only appended records at their overall positions' do
    @controller.request.accept = 'text/vnd.turbo-stream.html'
    @controller.instance_variable_set(:@append_results, @results.last(2))

    assert_equal 'append', log_payload[:response_kind]
    assert_equal [{ api: 'timdex', record_id: 'alma:789', position: 4 }], log_payload[:returned_results]
  end

  test 'FRBR group IDs stay attached to the returned record in HTML and Turbo' do
    @results.first[:frbr_group_id] = 'group-123'
    entry = { api: 'primo', record_id: 'alma123', frbr_group_id: 'group-123', position: 1 }
    assert_equal entry, log_payload[:returned_results].first
    refute log_payload.key?(:frbr_group_ids)
    refute log_payload[:returned_results].second.key?(:frbr_group_id)

    @controller.request = ActionDispatch::TestRequest.create
    @controller.request.accept = 'text/vnd.turbo-stream.html'
    @controller.instance_variable_set(:@append_results, @results.last(2))
    refute(log_payload[:returned_results].any? { |result| result.key?(:frbr_group_id) })

    @controller.instance_variable_set(:@append_results, @results)
    assert_equal entry, log_payload[:returned_results].first
  end

  test 'JSON logs the full response even when an append slice exists' do
    @controller.request.accept = 'application/json'
    @controller.instance_variable_set(:@append_results, [])

    assert_equal 3, log_payload[:returned_results_count]
  end

  test 'source specific pages and append responses use pagination positions' do
    @controller.instance_variable_set(:@active_tab, 'primo')
    @controller.instance_variable_set(:@pagination, { start: 21 })
    assert_equal [21, 22, 24], log_payload[:returned_results].pluck(:position)

    @controller.request = ActionDispatch::TestRequest.create
    @controller.request.accept = 'text/vnd.turbo-stream.html'
    @controller.instance_variable_set(:@append_results, @results)
    assert_equal [21, 22, 24], log_payload[:returned_results].pluck(:position)
  end

  test 'HTML errors and continuation responses do not log suppressed records' do
    @controller.instance_variable_set(:@errors, ['Backend error'])
    assert_equal 'error', log_payload[:search_outcome]
    assert_empty log_payload[:returned_results]

    @controller.instance_variable_set(:@errors, nil)
    @controller.instance_variable_set(:@show_primo_continuation, true)
    assert_empty log_payload[:returned_results]
  end

  test 'empty successful responses and HTTP failures have no returned IDs' do
    @controller.instance_variable_set(:@results, [])
    assert_equal 'success', log_payload[:search_outcome]
    assert_empty log_payload[:returned_results]

    @controller.instance_variable_set(:@results, @results)
    @controller.response.status = 500
    assert_equal 'error', log_payload[:search_outcome]
    assert_empty log_payload[:returned_results]
  end

  private

  def log_payload
    {}.tap { |payload| @controller.send(:append_info_to_payload, payload) }
  end
end
