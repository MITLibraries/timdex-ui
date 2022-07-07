module SearchHelper
  def displayed_fields
    ['title', 'title.exact_value', 'content_type', 'dates.value', 'contributors.value']
  end

  def trim_highlights(result)
    return unless result['highlight']&.any?

    result['highlight'].reject { |h| displayed_fields.include? h['matchedField'] }
  end
end
