class FulfillmentPolicy
  def initialize(result:)
    @result = result || {}
  end

  def primo_actions(record_link_enabled:)
    links.filter_map do |link|
      kind = link['kind'].to_s
      url = link['url']
      next if kind.blank? || url.blank?

      if full_record_kind?(kind)
        next unless record_link_enabled

        {
          label: 'View full record',
          url:,
          classes: 'button',
          data: {
            content_piece: 'View Full Record',
            action_type: 'view_full_record',
            action_source: 'primo'
          }
        }
      else
        {
          label: kind,
          url:,
          classes: 'button primo-link',
          data: {
            content_piece: kind,
            action_type: full_text_options_kind?(kind) ? 'full_text_options' : 'primo_link',
            action_source: 'primo'
          }
        }
      end
    end
  end

  # Browzine can render its own "Full-text options" button from full_record_url.
  # We only provide this URL when the normalized Primo links do not already
  # contain a full-text options action.
  def browzine_full_record_url
    return nil if existing_full_text_options?

    full_record_url
  end

  private

  attr_reader :result

  def existing_full_text_options?
    links.any? { |link| full_text_options_kind?(link['kind'].to_s) }
  end

  def links
    result[:links] || []
  end

  def full_record_url
    links.find { |link| full_record_kind?(link['kind']) }&.dig('url')
  end

  def full_record_kind?(kind)
    kind.to_s.downcase == 'full record'
  end

  def full_text_options_kind?(kind)
    kind.to_s.downcase == 'full-text options'
  end
end
