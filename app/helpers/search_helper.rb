module SearchHelper
  def displayed_fields
    ['title', 'title.exact_value', 'content_type', 'dates.value', 'contributors.value']
  end

  def trim_highlights(result)
    return unless result['highlight']&.any?

    result['highlight'].reject { |h| displayed_fields.include? h['matchedField'] }
  end

  def format_highlight_label(field_name)
    field_name = field_name.split('.').first if field_name.include?('.')
    field_name.underscore.humanize
  end

  def link_to_result(result)
    if result['source_link'].present?
      link_to(result['title'], result['source_link'])
    else
      result['title']
    end
  end

  def view_online(result)
    return unless result['source_link'].present?

    link_to 'View online', result['source_link'], class: 'button button-primary'
  end

  def view_record(record_id)
    link_to 'View full record', record_path(id: record_id), class: 'button button-primary'
  end

  # 'Coverage' and 'issued' seem to be the most prevalent types; 'coverage' is typically formatted as
  # 'YYYY', whereas 'issued' comes in a variety of formats.
  def parse_geo_dates(dates)
    relevant_dates = if dates&.any? { |date| date['kind'] == 'Issued' }
                       dates.select { |date| date['kind'] == 'Issued' }&.uniq
                     elsif dates&.any? { |date| date['kind'] == 'Coverage' }
                       dates.select { |date| date['kind'] == 'Coverage' }&.uniq
                     end
    return if relevant_dates.blank?

    # Taking the first date, somewhat arbitrarily, because returning something is likely better than returning nothing.
    relevant_date = relevant_dates.first['value']

    # If the date vaguely resembes a year, return it as is.
    return relevant_date if relevant_date.length == 4

    # If the date vaguely resembles 'YYYY-MM', 12/01/2020, or another unparsable date, extract the year.
    handle_unparsable_date(relevant_date)
  end

  def applied_keyword(query)
    relevant_terms = ['q']
    render_relevant_terms(query, relevant_terms)
  end

  def applied_geobox_terms(query)
    relevant_terms = %w[geoboxMinLatitude geoboxMaxLatitude geoboxMinLongitude geoboxMaxLongitude]
    render_relevant_terms(query, relevant_terms)
  end

  def applied_geodistance_terms(query)
    relevant_terms = %w[geodistanceLatitude geodistanceLongitude geodistanceDistance]
    render_relevant_terms(query, relevant_terms)
  end

  def applied_advanced_terms(query)
    relevant_terms = %w[title citation contributors fundingInformation identifiers locations subjects]
    render_relevant_terms(query, relevant_terms)
  end

  private

  # Query params need some treatment to look decent in the search summary panel.
  def readable_param(param)
    return 'Keyword anywhere' if param == 'q'
    return 'Authors' if param == 'contributors' && Feature.enabled?(:geodata)

    if param.starts_with?('geodistance')
      param = param.gsub('geodistance', '')
    elsif param.starts_with?('geobox')
      param = param.gsub(/geobox(Max|Min)/, '\1 ')
    end

    param.titleize.humanize
  end

  def render_relevant_terms(query, relevant_terms)
    applied_terms = query.select { |param, _value| relevant_terms.include?(param.to_s) }
    return unless applied_terms.present?

    applied_terms.filter_map { |param, value| "#{readable_param(param.to_s)}: #{value}" }
  end

  def handle_unparsable_date(date)
    if date.include? '-'
      extract_year(date, '-')
    elsif date.include? '/'
      extract_year(date, '/')
    end
  end

  def extract_year(date, delimiter)
    if date.split(delimiter).first.length == 4
      date.split(delimiter).first
    elsif date.split(delimiter).last.length == 4
      date.split(delimiter).last
    end
  end

  def primo_search_url(query_term)
    base_url = 'https://mit.primo.exlibrisgroup.com/discovery/search'
    params = {
      vid: ENV.fetch('PRIMO_VID'),
      query: "any,contains,#{query_term}"
    }
    "#{base_url}?#{params.to_query}"
  end
end
