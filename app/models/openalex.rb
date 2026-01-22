# frozen_string_literal: true

# OpenAlex API integration
# https://docs.openalex.org/how-to-use-the-api/api-overview
# https://docs.openalex.org/api-entities/works
class Openalex
  BASEURL = 'https://api.openalex.org'

  class LookupFailure < StandardError; end

  # enabled? confirms that the required environment variable is set.
  #
  # @return Boolean
  def self.enabled?
    openalex_email.present?
  end

  # OpenAlex accepts various identifier formats: full URI, short URN, or raw identifier
  # We are only supporting raw identifier lookups here for simplicity (ex: DOI without the "doi:" prefix) as that is
  # the shape of the data coming from Primo. We add the identifier type prefix accordingly.
  # Currently supported identifier types in OpenAlex are 'doi', 'pmid', 'pmcid', and 'mag'
  def self.work(identifier:, identifier_type: 'doi', openalex_client: nil)
    return nil unless enabled?

    # Check cache first
    cache_key = generate_cache_key(identifier_type, identifier)
    cached_result = Rails.cache.read(cache_key)
    return cached_result if cached_result.present?

    # Construct the OpenAlex Works endpoint URL
    url = "#{BASEURL}/works/#{identifier_type}:#{identifier}"

    openalex_http = setup(url, openalex_client)

    begin
      raw_response = openalex_http.timeout(6).get(url)
      raise LookupFailure, raw_response.status unless raw_response.status == 200

      json_response = JSON.parse(raw_response.to_s)

      result = extract_metadata(json_response)
      Rails.logger.debug(result)

      # Cache the result for 24 hours
      Rails.cache.write(cache_key, result, expires_in: 24.hours) if result.present?
      result
    rescue LookupFailure => e
      # 404s are expected for missing works, so only log unexpected statuses
      if e.message != '404 Not Found'
        Sentry.set_tags('mitlib.openalex_url': url)
        Sentry.set_tags('mitlib.openalex_status': e.message)
        Sentry.capture_message('Unexpected OpenAlex response status')
        Rails.logger.error("Unexpected OpenAlex response status: #{e.message}")
      end
      nil
    rescue HTTP::Error
      Rails.logger.error('OpenAlex connection error')
      { 'error' => 'A connection error has occurred' }
    rescue JSON::ParserError
      Rails.logger.error('OpenAlex parsing error')
      { 'error' => 'A parsing error has occurred' }
    end
  end

  def self.is_oa?(external_data)
    return false if external_data.blank?

    external_data.dig('open_access', 'is_oa') || false
  end

  # Using the OpenAlex best OA location logic. If we need to change the logic, we can update here by using locations
  # rather than best_oa_location from OpenAlex directly.
  def self.extract_metadata(external_data)
    return nil if external_data.blank? || external_data['id'].blank?
    return nil unless is_oa?(external_data)

    {
      record_id: external_data['id'],
      is_open: is_oa?(external_data),
      pdf_link: pdf_link(external_data),
      html_link: html_link(external_data),
      type: user_friendly_type(type(external_data))
    }
  end

  def self.pdf_link(external_data)
    return nil if external_data.blank? || external_data['best_oa_location'].blank?

    external_data['best_oa_location']['pdf_url']
  end

  def self.html_link(external_data)
    return nil if external_data.blank? || external_data['best_oa_location'].blank?

    external_data['best_oa_location']['landing_page_url']
  end

  def self.type(external_data)
    return nil if external_data.blank? || external_data['best_oa_location'].blank?

    external_data['best_oa_location']['version']
  end

  def self.openalex_email
    ENV.fetch('OPENALEX_EMAIL', nil)
  end

  def self.setup(url, openalex_client)
    openalex_client || HTTP.persistent(url)
                           .headers(accept: 'application/json',
                                    'User-Agent': "TIMDEX UI (#{openalex_email})")
  end

  def self.generate_cache_key(identifier_type, identifier)
    "openalex:works:#{identifier_type}:#{Digest::MD5.hexdigest(identifier)}"
  end

  def self.user_friendly_type(type_code)
    case type_code
    when 'acceptedVersion'
      'Accepted Version'
    when 'publishedVersion'
      'Published Version'
    when 'submittedVersion'
      'Submitted Version'
    else
      Sentry.set_tags('mitlib.openalex_type_code': type_code)
      Sentry.capture_message('Unexpected OpenAlex type code')
      Rails.logger.error("Unexpected OpenAlex type code: #{type_code}")

      type_code
    end
  end
end
