# TODO: Need some documentation block to explain what we use Libkey for...
class Libkey < ThirdIron
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
      Rails.logger.error("Unexpected Libkey response status: #{e.message}")
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
    return if external_data['data'].blank?

    {
      best_integrator_link: best_integrator_link(external_data),
      browzine_link: browzine_link(external_data),
      html_link: html_link(external_data),
      pdf_link: pdf_link(external_data),
      openurl_link: openurl_link(external_data)
    }
  end

  def self.openurl_link(external_data)
    return unless external_data['data']['linkResolverOpenUrl']&.present?

    {
      link: external_data['data']['linkResolverOpenUrl'],
      text: 'OpenURL Link'
    }
  end

  def self.pdf_link(external_data)
    return unless external_data['data']['fullTextFile']&.present?

    {
      link: external_data['data']['fullTextFile'],
      text: 'Get PDF'
    }
  end

  def self.html_link(external_data)
    return unless external_data['data']['contentLocation']&.present?

    {
      link: external_data['data']['contentLocation'],
      text: 'Read online'
    }
  end

  def self.browzine_link(external_data)
    return unless external_data['data']['browzineWebLink']&.present?

    {
      link: external_data['data']['browzineWebLink'],
      text: 'Browse journal issue'
    }
  end

  def self.best_integrator_link(external_data)
    return unless external_data['data']['bestIntegratorLink']

    # Skip generic 'Access Options' links. Clicking the title is prefered in this case rather than a button to the
    # link resolver which is missing context available on the record page.
    return if external_data['data']['bestIntegratorLink']['recommendedLinkText'] == 'Access Options'

    {
      link: external_data['data']['bestIntegratorLink']['bestLink'],
      text: external_data['data']['bestIntegratorLink']['recommendedLinkText'],
      type: external_data['data']['bestIntegratorLink']['linkType']
    }
  end

  def self.libkey_url(type, identifier)
    "#{BASEURL}/#{thirdiron_id}/articles/#{type}/#{identifier}?access_token=#{thirdiron_key}"
  end

  def self.setup(url, libkey_client)
    libkey_client || HTTP.persistent(url)
                         .headers(accept: 'application/json')
  end
end
