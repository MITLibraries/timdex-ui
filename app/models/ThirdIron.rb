class ThirdIron
  class LookupFailure < StandardError; end

  BASEURL = 'https://public-api.thirdiron.com/public/v1/libraries'.freeze

  # enabled? confirms that all required environment variables are set.
  #
  # @return Boolean
  def self.enabled?
    thirdiron_id.present? && thirdiron_key.present?
  end

  def self.thirdiron_id
    ENV.fetch('THIRDIRON_ID', nil)
  end

  def self.thirdiron_key
    ENV.fetch('THIRDIRON_KEY', nil)
  end
end
