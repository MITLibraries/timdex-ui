require 'test_helper'

class FeatureTest < ActiveSupport::TestCase
  test 'defined features default to false' do
    refute Feature.enabled?(:geodata)
    refute Feature.enabled?(:boolean_picker)
  end

  test 'undefined features return false' do
    refute Feature.enabled?(:undefined_feature)
  end

  test 'features can be enabled via environment variables' do
    ClimateControl.modify FEATURE_GEODATA: 'true' do
      assert Feature.enabled?(:geodata)
    end
  end

  test 'features can be disabled via environment variables' do
    ClimateControl.modify FEATURE_GEODATA: 'false' do
      refute Feature.enabled?(:geodata)
    end
  end

  test 'environment variables are case insensitive' do
    ClimateControl.modify FEATURE_GEODATA: 'TRUE' do
      assert Feature.enabled?(:geodata)
    end

    ClimateControl.modify FEATURE_GEODATA: 'True' do
      assert Feature.enabled?(:geodata)
    end

    ClimateControl.modify FEATURE_GEODATA: 'false' do
      refute Feature.enabled?(:geodata)
    end

    ClimateControl.modify FEATURE_GEODATA: 'FALSE' do
      refute Feature.enabled?(:geodata)
    end
  end

  test 'non true boolean values default to false' do
    ClimateControl.modify(
      FEATURE_GEODATA: 'invalid'
    ) do
      refute Feature.enabled?(:geodata)
    end

    ClimateControl.modify(
      FEATURE_GEODATA: '1'
    ) do
      refute Feature.enabled?(:geodata)
    end

    ClimateControl.modify(
      FEATURE_GEODATA: 'yes'
    ) do
      refute Feature.enabled?(:geodata)
    end
  end

  test 'feature names are case sensitive' do
    ClimateControl.modify FEATURE_GEODATA: 'true' do
      assert Feature.enabled?(:geodata)
      refute Feature.enabled?(:GDT)
    end
  end

  test 'multiple features can be controlled independently' do
    ClimateControl.modify(
      FEATURE_GEODATA: 'true',
      FEATURE_BOOLEAN_PICKER: 'false'
    ) do
      assert Feature.enabled?(:geodata)
      refute Feature.enabled?(:boolean_picker)
    end
  end
end
