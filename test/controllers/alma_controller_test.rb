require 'test_helper'

class AlmaControllerTest < ActionDispatch::IntegrationTest
  test 'alma sru route exists with no content' do
    get almasru_path

    assert_response :success
    assert response.body.blank?
  end

  test 'alma sru route returns nothing for gibberish content' do
    needle = 'foo'
    get almasru_path(doc_id: needle)

    assert_response :success
    assert response.body.blank?
  end

  test 'alma sru route returns full-text options when Alma-E is true' do
    VCR.use_cassette('alma sru no availability') do
      needle = 'alma9935053423706761'
      get almasru_path(doc_id: needle)

      assert_response :success
      assert_select 'a.button', { count: 1, text: 'Full-text options' }
    end
  end

  test 'alma sru route returns nothing when lookup has no AVA and no Alma-E' do
    VCR.use_cassette('alma sru nonexistent record') do
      needle = 'alma9900000000006761'
      get almasru_path(doc_id: needle)

      assert_response :success
      assert response.body.blank?
    end
  end

  test 'alma sru route returns availability for successful lookup' do
    VCR.use_cassette('alma sru single record') do
      needle = 'alma990014651640106761'
      get almasru_path(doc_id: needle)

      assert_response :success
      assert_select 'div.availability a', { count: 1 }
      refute_includes response.body, 'and other locations'
    end
  end

  test 'alma sru route returns one statement including "and other locations" with multiple AVA' do
    VCR.use_cassette('alma sru multiple records') do
      needle = 'alma990002935920106761'
      get almasru_path(doc_id: needle)

      assert_response :success
      assert_select 'div.availability a', { count: 1 }
      assert_includes response.body, 'and other locations'
    end
  end

  test 'alma sru route does nothing for valid id if required env undefined' do
    VCR.use_cassette('alma sru single record') do
      needle = 'alma990014651640106761'
      get almasru_path(doc_id: needle)

      assert_response :success
      refute response.body.blank?

      ClimateControl.modify(MIT_ALMA_URL: nil) do
        get almasru_path(doc_id: needle)

        assert_response :success
        assert response.body.blank?
      end
    end
  end
end
