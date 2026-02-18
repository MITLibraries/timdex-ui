# https://openlibrary.org/search.json?title=computational+fairy+tales
class Openlibrary
  def self.enabled?
    openlibrary_url.present?
  end

  def self.search(query, openlibrary_client: nil)
    return [] unless enabled?

    url = "#{openlibrary_url}?title=#{query}"

    openlibrary_http = setup(url, openlibrary_client)

    begin
      raw_response = openlibrary_http.timeout(6).get(url)

      json_response = JSON.parse(raw_response.to_s)

      json_response['docs'].first
    rescue StandardError => e
      Rails.logger.error("OpenLibrary search error: #{e.message}")
      []
    end
  end

  def self.setup(url, openlibrary_client)
    openlibrary_client || HTTP.persistent(url)
                              .headers(accept: 'application/json')
  end

  def self.openlibrary_url
    ENV.fetch('OPENLIBRARY_URL', nil)
  end
end
