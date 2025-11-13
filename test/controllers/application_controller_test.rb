require 'test_helper'

class ApplicationControllerTest < ActionDispatch::IntegrationTest
  test 'set_active_tab sets default to all when no feature flag or params' do
    assert_nil cookies[:last_tab]

    get root_path
    assert_select '#tab-to-target' do
      assert_select '[value=?]', 'all'
      refute_select '[value=?]', 'geodata'
      refute_select '[value=?]', 'primo'
      refute_select '[value=?]', 'timdex'
    end

    assert_equal cookies[:last_tab], 'all'
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

  test 'set_active_tab sets to param tab when provided' do
    get root_path, params: { tab: 'timdex' }

    assert_select '#tab-to-target' do
      refute_select '[value=?]', 'primo'
      refute_select '[value=?]', 'all'
      assert_select '[value=?]', 'timdex'
    end
  end

  test 'set_active_tab sets to param tab when provided even if cookie is set and updates cookie' do
    cookies[:last_tab] = 'timdex'
    get root_path, params: { tab: 'primo' }

    assert_select '#tab-to-target' do
      assert_select '[value=?]', 'primo'
      refute_select '[value=?]', 'geodata'
      refute_select '[value=?]', 'timdex'
      refute_select '[value=?]', 'all'
    end

    assert_equal cookies[:last_tab], 'primo'
  end

  test 'set_active_tab uses cookie last_tab when no param provided' do
    cookies[:last_tab] = 'timdex'
    get root_path
    assert_select '#tab-to-target' do
      refute_select '[value=?]', 'all'
      refute_select '[value=?]', 'primo'
      assert_select '[value=?]', 'timdex'
    end
  end

  test 'valid_tab returns true for valid tabs' do
    app_controller = ApplicationController.new

    assert app_controller.send(:valid_tab?, 'primo')
    assert app_controller.send(:valid_tab?, 'timdex') 
    assert app_controller.send(:valid_tab?, 'all')
  end

  test 'valid_tab returns false for invalid tabs' do
    app_controller = ApplicationController.new

    refute app_controller.send(:valid_tab?, 'foo')
    refute app_controller.send(:valid_tab?, '')
    refute app_controller.send(:valid_tab?, nil)
  end

  test 'set_active_tab ignores invalid tab parameter and uses default' do
    get root_path, params: { tab: 'invalid_tab' }

    assert_select '#tab-to-target' do
      assert_select '[value=?]', 'all'
      refute_select '[value=?]', 'invalid_tab'
    end

    assert_equal cookies[:last_tab], 'all'
  end

  test 'set_active_tab ignores invalid cookie value and uses default' do
    cookies[:last_tab] = 'invalid_cookie_value'
    get root_path

    assert_select '#tab-to-target' do
      assert_select '[value=?]', 'all'
      refute_select '[value=?]', 'invalid_cookie_value'
    end

    assert_equal cookies[:last_tab], 'all'
  end

  test 'set_active_tab prioritizes valid param over invalid cookie' do
    cookies[:last_tab] = 'invalid_cookie'
    get root_path, params: { tab: 'timdex' }

    assert_select '#tab-to-target' do
      refute_select '[value=?]', 'invalid_cookie'
      assert_select '[value=?]', 'timdex'
    end

    assert_equal cookies[:last_tab], 'timdex'
  end

  test 'set_active_tab falls back to valid cookie when param is invalid' do
    cookies[:last_tab] = 'primo'
    get root_path, params: { tab: 'foo' }

    assert_select '#tab-to-target' do
      refute_select '[value=?]', 'foo'
      assert_select '[value=?]', 'primo'
    end

    assert_equal cookies[:last_tab], 'primo'
  end
end
