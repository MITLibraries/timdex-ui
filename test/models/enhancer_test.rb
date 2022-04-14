require 'test_helper'

class EnhancerTest < ActiveSupport::TestCase
  test 'enhanced_query with no matched patterns returns raw query and q' do
    params = {}
    params[:q] = 'hallo'

    eq = Enhancer.new(params)
    assert_equal params[:q], eq.enhanced_query[:q]
  end

  test 'enhanced_query does not set values for unmatched term_patterns' do
    params = {}
    params[:q] = 'hallo'

    eq = Enhancer.new(params)

    assert_nil eq.enhanced_query[:issn]
    assert_nil eq.enhanced_query[:isbn]
  end

  test 'enhanced_query returns keys and values for matched patterns' do
    params = {}
    params[:q] = 'hallo 978-3-16-148410-0 goodbye'

    eq = Enhancer.new(params)

    assert_equal '978-3-16-148410-0', eq.enhanced_query[:isbn]
  end

  test 'enhanced_query can match multiple patterns' do
    params = {}
    params[:q] = 'hallo 978-3-16-148410-0 goodbye 1234-5678 popcorn'

    eq = Enhancer.new(params)

    assert_equal '978-3-16-148410-0', eq.enhanced_query[:isbn]
    assert_equal '1234-5678', eq.enhanced_query[:issn]
  end
end
