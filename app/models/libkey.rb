# TODO: Need some documentation block to explain what we use Libkey for...
class Libkey
  class LookupFailure < StandardError; end

  BASEURL = 'https://public-api.thirdiron.com/public/v1/libraries'.freeze

  # enabled? confirms that all required environment variables are set.
  #
  # @return Boolean
  def self.enabled?
    libkey_id.present? && libkey_key.present?
  end

  def self.lookup(type:, identifier:, libkey_client: nil)
    return unless enabled?
    return unless %w[doi pmid].include?(type)

    url = libkey_url(type, identifier)

    libkey_http = setup(url, libkey_client)

    begin
      raw_response = libkey_http.timeout(6).get(url)
      raise LookupFailure, raw_response.status unless raw_response.status == 200

      json_response = JSON.parse(raw_response.to_s)
      extract_metadata(json_response)
    rescue LookupFailure => e
      Sentry.set_tags('mitlib.libkeyurl': url)
      Sentry.set_tags('mitlib.libkeystatus': e.message)
      Sentry.capture_message('Unexpected Libkey response status')
      nil
    rescue HTTP::Error
      Rails.logger.error('Libkey connection error')
      { 'error' => 'A connection error has occurred' }
    rescue JSON::ParserError
      Rails.logger.error('Libkey parsing error')
      { 'error' => 'A parsing error has occurred' }
    end
  end

  def self.extract_metadata(external_data)
    return unless external_data['data']['bestIntegratorLink']

    {
      link: external_data['data']['bestIntegratorLink']['bestLink'],
      text: external_data['data']['bestIntegratorLink']['recommendedLinkText'],
      type: external_data['data']['bestIntegratorLink']['linkType'] # Not sure whether this belongs here.
    }
  end

  def self.libkey_id
    ENV.fetch('LIBKEY_ID', nil)
  end

  def self.libkey_key
    ENV.fetch('LIBKEY_KEY', nil)
  end

  def self.libkey_url(type, identifier)
    "#{BASEURL}/#{libkey_id}/articles/#{type}/#{identifier}?access_token=#{libkey_key}"
  end

  def self.setup(url, libkey_client)
    libkey_client || HTTP.persistent(url)
                         .headers(accept: 'application/json')
  end
end
