require 'test_helper'

class EnhancerPatternsTest < ActiveSupport::TestCase
  test 'ISBN detected in a string' do
    enhanced_query = {}

    actual = EnhancerPatterns.new(enhanced_query, 'test 978-3-16-148410-0 test').enhanced_query
    assert_equal('978-3-16-148410-0', actual[:isbn])
  end

  test 'ISBN-10 examples' do
    enhanced_query = {}

    # from wikipedia
    samples = ['99921-58-10-7', '9971-5-0210-0', '960-425-059-0', '80-902734-1-6', '85-359-0277-5',
               '1-84356-028-3', '0-684-84328-5', '0-8044-2957-X', '0-85131-041-9', '93-86954-21-4', '0-943396-04-2',
               '0-9752298-0-X']

    samples.each do |isbn|
      actual = EnhancerPatterns.new(enhanced_query, isbn).enhanced_query
      assert_equal(isbn, actual[:isbn])
    end
  end

  test 'ISBN-13 examples' do
    enhanced_query = {}

    samples = ['978-99921-58-10-7', '979-9971-5-0210-0', '978-960-425-059-0', '979-80-902734-1-6', '978-85-359-0277-5',
               '979-1-84356-028-3', '978-0-684-84328-5', '979-0-8044-2957-X', '978-0-85131-041-9', '979-93-86954-21-4',
               '978-0-943396-04-2', '979-0-9752298-0-X']

    samples.each do |isbn|
      actual = EnhancerPatterns.new(enhanced_query, isbn).enhanced_query
      assert_equal(isbn, actual[:isbn])
    end
  end

  test 'not ISBNs' do
    enhanced_query = {}

    samples = ['orange cats like popcorn', '1234-6798', 'another ISBN not found here']

    samples.each do |notisbn|
      actual = EnhancerPatterns.new(enhanced_query, notisbn).enhanced_query
      assert_nil(actual[:isbn])
    end
  end

  test 'ISBNs need boundaries' do
    enhanced_query = {}

    samples = ['990026671500206761', '979-0-9752298-0-XYZ']
    # note, there is a theoretical case of `asdf979-0-9752298-0-X` returning as an ISBN 10 even though it doesn't
    # have a word boundary because the `-` is treated as a boundary so `0-9752298-0-X` would be an ISBN10. We can
    # consider whether we care in the future as we look for incorrect real-world matches.

    samples.each do |notisbn|
      actual = EnhancerPatterns.new(enhanced_query, notisbn).enhanced_query
      assert_nil(actual[:isbn])
    end
  end

  test 'ISSNs detected in a string' do
    enhanced_query = {}

    actual = EnhancerPatterns.new(enhanced_query, 'test 1234-5678 test').enhanced_query
    assert_equal('1234-5678', actual[:issn])
  end

  test 'ISSN examples' do
    enhanced_query = {}

    samples = %w[2049-3630 0000-0019 1864-0761 1877-959X 1877-7740 1877-5683 1440-172X 1040-5631]

    samples.each do |issn|
      actual = EnhancerPatterns.new(enhanced_query, issn).enhanced_query
      assert_equal(issn, actual[:issn])
    end
  end

  test 'not ISSN examples' do
    enhanced_query = {}

    samples = ['orange cats like popcorn', '12346798', 'another ISSN not found here', '99921-58-10-7']

    samples.each do |notissn|
      actual = EnhancerPatterns.new(enhanced_query, notissn).enhanced_query
      assert_nil(actual[:issn])
    end
  end

  test 'ISSNs need boundaries' do
    enhanced_query = {}

    actual = EnhancerPatterns.new(enhanced_query, '12345-5678 1234-56789').enhanced_query
    assert_nil(actual[:issn])
  end
end
