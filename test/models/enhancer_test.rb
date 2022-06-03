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

  # Page parameter
  test 'enhanced_query recieves page values in positive numbers' do
    params = {}
    params[:q] = 'singleton'
    params[:page] = 3

    eq = Enhancer.new(params)
    assert_equal 3, eq.enhanced_query[:page]
  end

  test 'enhanced_query recieves page values as strings' do
    params = {}
    params[:q] = 'singleton'
    params[:page] = '3'

    eq = Enhancer.new(params)
    assert_equal 3, eq.enhanced_query[:page]
  end

  test 'enhanced_query converts decimal page values to integers' do
    params = {}
    params[:q] = 'singleton'
    params[:page] = '6.02'

    eq = Enhancer.new(params)
    assert_equal 6, eq.enhanced_query[:page]
  end

  test 'enhanced_query sets a default page value if none received' do
    params = {}
    params[:q] = 'singleton'

    eq = Enhancer.new(params)
    assert_equal 1, eq.enhanced_query[:page]
  end

  test 'enhanced_query deals with negative page numbers' do
    params = {}
    params[:q] = 'singleton'
    params[:page] = '-100'

    eq = Enhancer.new(params)
    assert_equal 1, eq.enhanced_query[:page]
  end

  test 'enhanced_query deals with gibberish' do
    params = {}
    params[:q] = 'singleton'
    params[:page] = 'foo'

    eq = Enhancer.new(params)
    assert_equal 1, eq.enhanced_query[:page]
  end
end
