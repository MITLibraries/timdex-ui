# Encapsulates Primo fulfillment link rules for a single normalized Primo result.
#
# Scope:
# - Primary responsibility: shape Primo-derived links (`result[:links]`) into
#   renderable UI actions (labels, classes, and action metadata).
# - This policy is intentionally scoped to Primo results, though additional
#   policies may be needed later.
# - It does not model all provider behaviors end-to-end (for example, LibKey,
#   OpenAlex, or TIMDEX result rendering paths).
# - It includes one Browzine helper for a 'Full-text options' link that points
#   to Primo's full-record URL. This is a fallback when the Primo normalizer
#   does not provide such a link.
#
# Why this exists:
# - The result partial previously had nested branching to decide which Primo
#   actions should render and when Browzine should receive a full-record URL.
# - Moving those rules here keeps the view declarative and gives us a focused,
#   unit-testable place to evolve fulfillment behavior.
class PrimoFulfillmentPolicy
  def initialize(result:)
    @result = result || {}
  end

  # Returns the normalized list of Primo-originated actions to render.
  #
  # @param record_link_enabled [Boolean] when true, include "View full record"
  #   (derived from Primo's "full record" link). When false, suppress that
  #   action but keep other Primo fulfillment links.
  # @return [Array<Hash>] action hashes with :label, :url, :classes, and :data
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

  # Returns the full-record URL to pass to Browzine for its optional
  # "Full-text options" action.
  #
  # If Primo already exposes a "Full-text options" link, we return nil so
  # Browzine does not emit a duplicate full-text action for the same record.
  #
  # @return [String, nil]
  def browzine_full_record_url
    return nil if existing_full_text_options?

    full_record_url
  end

  private

  def existing_full_text_options?
    links.any? { |link| full_text_options_kind?(link['kind'].to_s) }
  end

  def links
    @result[:links] || []
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
