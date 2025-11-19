require 'test_helper'

class ApplicationControllerUnitTest < ActionController::TestCase
  setup do
    @controller = ApplicationController.new
  end

  test '#primo_tabs returns expected tabs' do
    assert_equal %w[alma cdi primo], @controller.primo_tabs
  end

  test '#timdex_tabs returns expected tabs' do
    assert_equal %w[aspace timdex timdex_alma website], @controller.timdex_tabs
  end

  test '#all_tabs includes both primo and timdex tabs as well as all tab' do
    expected = %w[all alma cdi primo aspace timdex timdex_alma website]
    assert_equal expected, @controller.all_tabs
  end

  test '#valid_tab? returns true for valid tabs' do
    assert @controller.send(:valid_tab?, 'all')
    assert @controller.send(:valid_tab?, 'alma')
    assert @controller.send(:valid_tab?, 'timdex')
  end

  test '#valid_tab? returns false for invalid tabs' do
    refute @controller.send(:valid_tab?, 'invalid')
    refute @controller.send(:valid_tab?, '')
  end

  test 'set_active_tab defaults @active_tab to all when no params or cookies are set' do
    @controller.stubs(:params).returns({})
    @controller.stubs(:cookies).returns({})
    @controller.set_active_tab
    assert_equal 'all', @controller.instance_variable_get(:@active_tab)
  end

  test 'set_active_tab sets @active_tab to tab when tab params is valid' do
    @controller.stubs(:params).returns({ tab: 'primo' })
    @controller.stubs(:cookies).returns({})
    @controller.set_active_tab
    assert_equal 'primo', @controller.instance_variable_get(:@active_tab)
  end

  test 'set_active_tab sets @active_tab to all when tab params is invalid and no cookie is set' do
    @controller.stubs(:params).returns({ tab: 'supertab' })
    @controller.stubs(:cookies).returns({})
    @controller.set_active_tab
    assert_equal 'all', @controller.instance_variable_get(:@active_tab)
  end

  test 'set_active_tab sets @active_tab to cookie value when tab params is invalid and valid cookie is set' do
    @controller.stubs(:params).returns({ tab: 'supertab' })
    @controller.stubs(:cookies).returns({ last_tab: 'timdex' })
    @controller.set_active_tab
    assert_equal 'timdex', @controller.instance_variable_get(:@active_tab)
  end

  test 'set_active_tab sets @active_tab to all value when tab params is invalid and cookie is invalid' do
    @controller.stubs(:params).returns({ tab: 'supertab' })
    @controller.stubs(:cookies).returns({ last_tab: 'woohoo' })
    @controller.set_active_tab
    assert_equal 'all', @controller.instance_variable_get(:@active_tab)
  end
end
