require 'digest'

# Small utility to produce a stable cache key for a query hash.
# Keeps key-generation logic in one place so callers (controllers, services)
# can share the same behavior.
class CacheKeyGenerator
  # Return an MD5 hex digest for the supplied query hash.
  # Ensures deterministic ordering by sorting keys (converted to symbols)
  # before stringifying.
  #
  # @param query [Hash]
  # @return [String] MD5 hex digest
  def self.call(query)
    sorted = query.sort_by { |k, _v| k.to_sym }.to_h
    Digest::MD5.hexdigest(sorted.to_s)
  end
end
