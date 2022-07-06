require 'test_helper'

class SearchHelperTest < ActionView::TestCase
  include SearchHelper

  test 'removes displayed fields from highlights' do
    result = { 'highlight' => [{ 'matchedField' => 'title', 'matchedPhrases' => 'Very important data' },
                               { 'matchedField' => 'title.exact_value', 'matchedPhrases' => 'Very important data' },
                               { 'matchedField' => 'content_type', 'matchedPhrases' => 'Dataset' },
                               { 'matchedField' => 'dates.value', 'matchedPhrases' => '2022' },
                               { 'matchedField' => 'contributors.value', 'matchedPhrases' => 'Jane Datascientist' }] }
    assert_empty trim_highlights(result)
  end

  test 'does not remove undisplayed fields from highlights' do
    result = { 'highlight' => [{ 'matchedField' => 'summary', 'matchedPhrases' => 'Have some data' }] }
    assert_equal [{ 'matchedField' => 'summary', 'matchedPhrases' => 'Have some data' }], trim_highlights(result)
  end

  test 'returns correct set of highlights when result includes displayed and undisplayed fields' do
    result = { 'highlight' => [{ 'matchedField' => 'title', 'matchedPhrases' => 'Very important data' },
                           { 'matchedField' => 'content_type', 'matchedPhrases' => 'Dataset' },
                           { 'matchedField' => 'summary', 'matchedPhrases' => '2022' },
                           { 'matchedField' => 'citation', 'matchedPhrases' => 'Datascientist, Jane' }] }
    assert_equal [{ 'matchedField' => 'summary', 'matchedPhrases' => '2022' },
                 { 'matchedField' => 'citation', 'matchedPhrases' => 'Datascientist, Jane' }], trim_highlights(result)
  end
end
