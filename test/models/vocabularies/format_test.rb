require 'test_helper'

class VocabularyFormatTest < ActiveSupport::TestCase
  test 'lookup method returns better values where we know them' do
    value = 'BKSE'
    output = Vocabularies::Format.lookup(value)
    assert_equal output, 'eBook'
  end

  test 'lookup method returns sentence case as a default' do
    value = 'UNEXPECTED VALUE'
    output = Vocabularies::Format.lookup(value)
    assert_equal output, 'Unexpected value'
  end
end
