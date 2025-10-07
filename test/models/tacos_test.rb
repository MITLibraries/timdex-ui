require 'test_helper'

class TacosConnectionError
  def timeout(_)
    self
  end

  def post(_url, body:)
    raise HTTP::ConnectionError, "forced connection failure"
  end
end

class TacosParsingError
  def timeout(_)
    self
  end

  def post(_url, body:)
    'This is not valid json'
  end
end

class TacosTest < ActiveSupport::TestCase
  test 'TACOS model has a call method that reflects a search term back' do
    VCR.use_cassette('tacos popcorn') do
      searchterm = 'popcorn'

      result = Tacos.analyze(searchterm)

      assert_instance_of Hash, result
      assert_equal searchterm, result['data']['logSearchEvent']['phrase']
    end
  end

  test 'TACOS model will use ENV to populate the sourceSystem value' do
    VCR.use_cassette('tacos fake system') do
      ClimateControl.modify(TACOS_SOURCE: 'faked') do
        result = Tacos.analyze('popcorn')

        assert_equal 'faked', result['data']['logSearchEvent']['source']
      end
    end
  end

  test 'TACOS model catches connection errors' do
    tacos_client = TacosConnectionError.new

    result = Tacos.analyze('popcorn', tacos_client)

    assert_instance_of Hash, result
    assert_equal 'A connection error has occurred', result['error']
  end

  test 'TACOS model catches parsing errors' do
    tacos_client = TacosParsingError.new

    result = Tacos.analyze('popcorn', tacos_client)

    assert_instance_of Hash, result
    assert_equal 'A parsing error has occurred', result['error']
  end
end
