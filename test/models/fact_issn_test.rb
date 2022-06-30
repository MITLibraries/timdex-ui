require 'test_helper'

class FactIssnTest < ActiveSupport::TestCase
  test 'validate method rejects gibberish ISSN' do
    candidate = 'asdf'
    fact = FactIssn.new
    refute fact.validate(candidate)
  end

  test 'validate method rejects ISSNs with wrong check digit' do
    candidates = %w[
      1234-5678
      2015-2016
      1460-2441
      1460-2442
      1460-2443
      1460-2444
      1460-2445
      1460-2446
      1460-2447
      1460-2448
      1460-2449
      1460-2440
      0250-6331
      0250-6332
      0250-6333
      0250-6334
      0250-6336
      0250-6337
      0250-6338
      0250-6339
      0250-6330
      0250-633x
      0250-633X
    ]
    fact = FactIssn.new
    candidates.each do |candidate|
      refute fact.validate(candidate)
    end
  end

  test 'validate method accepts ISSNs with correct check digit' do
    candidates = %w[
      1460-244X
      2015-223x
      0250-6335
      0973-7758
    ]
    fact = FactIssn.new
    candidates.each do |candidate|
      assert fact.validate(candidate)
    end
  end
end
