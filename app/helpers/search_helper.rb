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
end
