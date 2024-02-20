require 'test_helper'

class FormHelperTest < ActionView::TestCase
  include FormHelper

  test 'checkbox is checked if source is only source in params' do
    source = 'hallo'
    params = { sourceFilter: ['hallo'] }
    expected = "<div class='field-subitem'>
      <label class='field-checkbox'>
        <input type='checkbox' value='hallo' name='sourceFilter[]'
               class='source' checked>
        hallo
      </label>
    </div>"
    actual = source_checkbox(source, params)

    assert_equal(expected, actual)
  end

  test 'checkbox is checked if source is one source in params' do
    source = 'hallo'
    params = { sourceFilter: ['popcorn', 'hallo', 'dspace@mit'] }
    expected = "<div class='field-subitem'>
      <label class='field-checkbox'>
        <input type='checkbox' value='hallo' name='sourceFilter[]'
               class='source' checked>
        hallo
      </label>
    </div>"
    actual = source_checkbox(source, params)

    assert_equal(expected, actual)
  end

  test 'checkbox is unchecked if no sources are in params' do
    source = 'hallo'
    params = {}
    expected = "<div class='field-subitem'>
      <label class='field-checkbox'>
        <input type='checkbox' value='hallo' name='sourceFilter[]'
               class='source'>
        hallo
      </label>
    </div>"
    actual = source_checkbox(source, params)

    assert_equal(expected, actual)
  end

  test 'checkbox is unchecked if source is not one of sources in params' do
    source = 'hallo'
    params = { source: ['popcorn', 'nothallo', 'dspace@mit'] }
    expected = "<div class='field-subitem'>
      <label class='field-checkbox'>
        <input type='checkbox' value='hallo' name='sourceFilter[]'
               class='source'>
        hallo
      </label>
    </div>"
    actual = source_checkbox(source, params)

    assert_equal(expected, actual)
  end
end
