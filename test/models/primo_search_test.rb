require 'test_helper'

class PrimoSearchTest < ActiveSupport::TestCase
  # Assumes env is correctly set in .env.test.
  test 'initializes successfully with all required environment variables' do
    assert_nothing_raised do
      PrimoSearch.new
    end
  end

  test 'raises error when PRIMO_API_URL is missing' do
    ClimateControl.modify(PRIMO_API_URL: nil) do
      error = assert_raises(ArgumentError) do
        PrimoSearch.new
      end
      assert_match(/PRIMO_API_URL/, error.message)
      assert_match(/Required Primo environment variables are not set/, error.message)
    end
  end

  test 'raises error when PRIMO_API_KEY is missing' do
    ClimateControl.modify(PRIMO_API_KEY: nil) do
      error = assert_raises(ArgumentError) do
        PrimoSearch.new
      end
      assert_match(/PRIMO_API_KEY/, error.message)
    end
  end

  test 'raises error when multiple environment variables are missing' do
    ClimateControl.modify(PRIMO_API_URL: nil, PRIMO_VID: nil) do
      error = assert_raises(ArgumentError) do
        PrimoSearch.new
      end
      assert_match(/PRIMO_API_URL/, error.message)
      assert_match(/PRIMO_VID/, error.message)
    end
  end

  test 'search returns results' do
    VCR.use_cassette('primo_search_success') do
      search = PrimoSearch.new
      results = search.search('popcorn', 10)
      assert_kind_of Hash, results
      assert_not_nil results['docs']
    end
  end

  # When regenerating the VCR cassette for this test, the API call must reach an error state. An
  # easy way to do this is to wrap the test in ClimateControl.modify(PRIMO_API_KEY: 'foo') ... end
  test 'handles failed search' do
    VCR.use_cassette('primo_search_error') do
      search = PrimoSearch.new
      assert_raises(RuntimeError) do
        search.search('test', 10)
      end
    end
  end

  test 'sanitizes search terms' do
    search = PrimoSearch.new

    # spaces, colons, commas which historically have been problems
    clean_term = search.send(:clean_term, 'test: search, term')
    assert_equal 'test%3A+search%2C+term', clean_term

    # double quotes
    clean_term = search.send(:clean_term, '"hello world"')
    assert_equal '%22hello+world%22', clean_term

    # our previous logic mangled this and resulted in bad results
    clean_term = search.send(:clean_term, 'c++')
    assert_equal 'c%2B%2B', clean_term

    # full citation that has many of the features that have lead to problematic encoding
    clean_term = search.send(:clean_term,
                             'Fuzuloparib with or without apatinib as maintenance therapy in newly diagnosed, advanced ovarian cancer (FZOCUS-1): A multicenter, randomized, double-blind, placebo-controlled phase 3 trial. Wu L, et al. CA Cancer J Clin. 2026.')
    assert_equal 'Fuzuloparib+with+or+without+apatinib+as+maintenance+therapy+in+newly+diagnosed%2C+advanced+ovarian+cancer+%28FZOCUS-1%29%3A+A+multicenter%2C+randomized%2C+double-blind%2C+placebo-controlled+phase+3+trial.+Wu+L%2C+et+al.+CA+Cancer+J+Clin.+2026.',
                 clean_term
  end

  test 'sets timeout from ENV' do
    ClimateControl.modify(PRIMO_TIMEOUT: '15') do
      search = PrimoSearch.new
      assert_equal 15.0, search.send(:http_timeout)
    end
  end

  test 'uses default timeout' do
    ClimateControl.modify(PRIMO_TIMEOUT: nil) do
      search = PrimoSearch.new
      assert_equal 6, search.send(:http_timeout)
    end
  end

  test 'search_url includes offset parameter when provided' do
    search = PrimoSearch.new
    url = search.send(:search_url, 'test', 20, 40)

    assert_match(/&offset=40/, url)
    assert_match(/&limit=20/, url)
    assert_match(/q=any,contains,test/, url)
  end

  test 'search_url excludes offset parameter when zero' do
    search = PrimoSearch.new
    url = search.send(:search_url, 'test', 20, 0)

    refute_match(/&offset=/, url)
    assert_match(/&limit=20/, url)
    assert_match(/q=any,contains,test/, url)
  end

  test 'search_url excludes offset parameter when not provided' do
    search = PrimoSearch.new
    url = search.send(:search_url, 'test', 20)

    refute_match(/&offset=/, url)
    assert_match(/&limit=20/, url)
    assert_match(/q=any,contains,test/, url)
  end
end
