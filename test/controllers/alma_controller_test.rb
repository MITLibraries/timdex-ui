require 'test_helper'

class AlmaControllerTest < ActionDispatch::IntegrationTest
  test 'alma sru route exists with no content' do
    get almasru_path

    assert :success
    assert response.body.blank?
  end

  test 'alma sru route returns nothing for gibberish content' do
    needle = 'foo'
    get almasru_path(doc_id: needle)

    assert :success
    assert response.body.blank?
  end

  test 'alma sru route returns nothing if lookup returns content with no AVA' do
    VCR.use_cassette('alma sru no availability') do
      needle = 'alma9935053423706761'
      get almasru_path(doc_id: needle)

      assert :success
      assert response.body.blank?
    end
  end

  test 'alma sru route returns HTML for successful lookup' do
    VCR.use_cassette('alma sru single record') do
      needle = 'alma990014651640106761'
      get almasru_path(doc_id: needle)

      assert :success
      assert_select 'div.availability a', { count: 1 }
      refute_includes response.body, 'and other locations'
    end
  end

  test 'alma sru route returns one statement including "and other locations" with multiple AVA' do
    VCR.use_cassette('alma sru multiple records') do
      needle = 'alma990002935920106761'
      get almasru_path(doc_id: needle)

      assert :success
      assert_select 'div.availability a', { count: 1 }
      assert_includes response.body, 'and other locations'
    end
  end

  test 'alma sru route does nothing for valid id if required env undefined' do
    VCR.use_cassette('alma sru single record') do
      needle = 'alma990014651640106761'
      get almasru_path(doc_id: needle)

      assert :success
      refute response.body.blank?

      ClimateControl.modify(MIT_ALMA_URL: nil) do
        get almasru_path(doc_id: needle)

        assert :success
        assert response.body.blank?
      end
    end
  end
end
