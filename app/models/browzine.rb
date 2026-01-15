# https://thirdiron.atlassian.net/wiki/spaces/BrowZineAPIDocs/pages/66191466/Journal+Availability+Endpoint
class Browzine < ThirdIron
  def self.lookup(issn:, browzine_client: nil)
    return unless enabled?

    url = browzine_url(issn&.tr('-', ''))
    browzine_http = setup(url, browzine_client)

    begin
      raw_response = browzine_http.timeout(6).get(url)
      raise LookupFailure, raw_response.status unless raw_response.status == 200

      json_response = JSON.parse(raw_response.to_s)
      extract_metadata(json_response)
    rescue LookupFailure => e
      Sentry.set_tags('mitlib.browzineurl': url)
      Sentry.set_tags('mitlib.browzinestatus': e.message)
      Sentry.capture_message('Unexpected Browzine response status')
      Rails.logger.error("Unexpected Browzine response status: #{e.message}")
      nil
    rescue HTTP::Error
      Rails.logger.error('Browzine connection error')
      { 'error' => 'A connection error has occurred' }
    rescue JSON::ParserError
      Rails.logger.error('Browzine parsing error')
      { 'error' => 'A parsing error has occurred' }
    end
  end

  def self.extract_metadata(json_response)
    return if json_response['data'].blank?

    {
      browzine_link: browzine_link(json_response)
    }
  end

  def self.browzine_link(json_response)
    return unless json_response['data'][0]['browzineWebLink']&.present?

    {
      link: json_response['data'][0]['browzineWebLink'],
      text: 'View journal contents'
    }
  end

  # :library_id/search
  def self.browzine_url(issn)
    "#{BASEURL}/#{thirdiron_id}/search?issns=#{issn}&access_token=#{thirdiron_key}"
  end

  def self.setup(url, browzine_client)
    browzine_client || HTTP.persistent(url)
                           .headers(accept: 'application/json')
  end
end
