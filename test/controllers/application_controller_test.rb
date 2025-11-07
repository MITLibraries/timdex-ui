require 'test_helper'

class ApplicationControllerTest < ActionDispatch::IntegrationTest
  test 'set_active_tab sets default to primo when no feature flag or params' do
    assert_nil cookies[:last_tab]

    get root_path
    assert_select '#tab-to-target' do
      assert_select '[value=?]', 'primo'
      refute_select '[value=?]', 'geodata'
      refute_select '[value=?]', 'timdex'
    end

    assert_equal cookies[:last_tab], 'primo'
  end

  test 'set_active_tab sets to geodata when feature flag enabled' do
    skip 'Geodata uses a different form so we do no set the tab this way'
    ClimateControl.modify FEATURE_GEODATA: 'true' do
      get root_path
      assert_select '#tab-to-target' do
        refute_select '[value=?]', 'primo'
        assert_select '[value=?]', 'geodata'
        refute_select '[value=?]', 'timdex'
      end
    end
  end

  test 'set_active_tab sets to geodata when feature flag enabled even if param is passed' do
    skip 'Geodata uses a different form'
    ClimateControl.modify FEATURE_GEODATA: 'true' do
      get root_path, params: { tab: 'primo' }
      assert_select '#tab-to-target' do
        refute_select '[value=?]', 'primo'
        assert_select '[value=?]', 'geodata'
        refute_select '[value=?]', 'timdex'
      end
    end
  end

  test 'set_active_tab sets to param tab when provided' do
    get root_path, params: { tab: 'timdex' }

    assert_select '#tab-to-target' do
      refute_select '[value=?]', 'primo'
      refute_select '[value=?]', 'geodata'
      assert_select '[value=?]', 'timdex'
    end
  end

  test 'set_active_tab sets to param tab when provided even if cookie is set and updates cookie' do
    cookies[:last_tab] = 'timdex'
    get root_path, params: { tab: 'geodata' }

    assert_select '#tab-to-target' do
      refute_select '[value=?]', 'primo'
      assert_select '[value=?]', 'geodata'
      refute_select '[value=?]', 'timdex'
    end

    assert_equal cookies[:last_tab], 'geodata'
  end

  test 'set_active_tab uses cookie last_tab when no param provided' do
    cookies[:last_tab] = 'timdex'
    get root_path
    assert_select '#tab-to-target' do
      refute_select '[value=?]', 'primo'
      refute_select '[value=?]', 'geodata'
      assert_select '[value=?]', 'timdex'
    end
  end
end
