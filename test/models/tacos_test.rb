require 'test_helper'

class TacosTest < ActiveSupport::TestCase
  test 'TACOS model has a call method that reflects a search term back' do
    VCR.use_cassette('tacos popcorn') do
      searchterm = 'popcorn'

      result = Tacos.call(searchterm)

      assert_instance_of Hash, result
      assert_equal searchterm, result['data']['logSearchEvent']['phrase']
    end
  end

  test 'TACOS model will use ENV to populate the sourceSystem value' do
    VCR.use_cassette('tacos fake system') do
      ClimateControl.modify(TACOS_SOURCE: 'faked') do
        result = Tacos.call('popcorn')

        assert_equal 'faked', result['data']['logSearchEvent']['source']
      end
    end
  end
end
