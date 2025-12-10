require 'test_helper'

class ApplicationControllerTest < ActionDispatch::IntegrationTest
  test 'set_active_tab sets default to all when no feature flag or params' do
    get root_path
    assert_select '#tab-to-target' do
      assert_select '[value=?]', 'all'
      refute_select '[value=?]', 'geodata'
      refute_select '[value=?]', 'primo'
      refute_select '[value=?]', 'timdex'
    end
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

  test 'set_active_tab sets to param tab when provided (param takes precedence)' do
    get root_path, params: { tab: 'primo' }

    assert_select '#tab-to-target' do
      assert_select '[value=?]', 'primo'
      refute_select '[value=?]', 'geodata'
      refute_select '[value=?]', 'timdex'
      refute_select '[value=?]', 'all'
    end
  end

  test 'set_active_tab defaults to all when no param provided' do
    get root_path
    assert_select '#tab-to-target' do
      assert_select '[value=?]', 'all'
      refute_select '[value=?]', 'primo'
      refute_select '[value=?]', 'timdex'
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
  end

  test 'set_active_tab ignores invalid cookie value and uses default' do
    get root_path

    assert_select '#tab-to-target' do
      assert_select '[value=?]', 'all'
      refute_select '[value=?]', 'invalid_cookie_value'
    end
  end

  test 'set_active_tab prioritizes valid param over invalid cookie' do
    get root_path, params: { tab: 'timdex' }

    assert_select '#tab-to-target' do
      assert_select '[value=?]', 'timdex'
    end
  end

  test 'set_active_tab with invalid param uses default' do
    get root_path, params: { tab: 'foo' }

    assert_select '#tab-to-target' do
      refute_select '[value=?]', 'foo'
      assert_select '[value=?]', 'all'
    end
  end
end
