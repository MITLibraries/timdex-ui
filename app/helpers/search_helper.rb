module SearchHelper
  def displayed_fields
    ['title', 'title.exact_value', 'content_type', 'dates.value', 'contributors.value']
  end

  def trim_highlights(result)
    return unless result['highlight']&.any?

    result['highlight'].reject { |h| displayed_fields.include? h['matchedField'] }
  end

  def view_online(result)
    return unless result['sourceLink'].present?

    link_to 'View online', result['sourceLink'], class: 'button button-primary green'
  end

  def view_record(record_id)
    link_to 'View full record', record_path(id: record_id), class: 'button button-primary green'
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

  private

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
end
