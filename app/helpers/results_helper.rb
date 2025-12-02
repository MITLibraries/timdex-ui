module ResultsHelper
  def results_summary(hits)
    hits.to_i >= 10_000 ? '10,000+ results' : "#{number_with_delimiter(hits)} results"
  end

  # Formats availability information for display.
  # Expects:
  # - status: a string indicating availability status
  # - location: an array with three elements: [library name, location name, call number]
  # - other_availability: a boolean string indicating if there is availability at other locations
  def availability(status, location, other_availability)
    blurb = case status.downcase
            # `available` is a common status used in Alma/Primo VE for items that are not checked out and should be
            # on the shelf
            when 'available'
              "#{icon('check')} Available in #{location(location)}"
            # `check_holdings`: unclear when (or if) this is used. Bento handled this so we did too assuming it was
            # meaningful
            when 'check_holdings'
              "#{icon('question')} May be available in #{location(location)}"
            # 'unavailable' is used for items that are checked out, missing, or otherwise not on the shelf
            when 'unavailable'
              "#{icon('times')} Not currently available in #{location(location)}"
            # Unclear if there are other statuses we should handle here. For now we log and display a generic message.
            else
              Rails.logger.error("Unhandled availability status: #{status.inspect}")
              "#{icon('question')} Uncertain availability in #{location(location)} #{status}"
            end

    blurb += ' and other locations.' if other_availability.present?

    # We are generating HTML in this helper, so we need to mark it as safe or it will be escaped in the view.
    blurb.html_safe
  end

  # Fontawesome helper. Currently only takes the icon name and assumes solid sharp style.
  # Could be extended later to default to these styles but allow overrides if appropriate.
  # Also defaults to aria-hidden true, which is probably what we want for icons used
  # purely for decoration. If an icon is used in a more meaningful way, we may want to extend this helper
  # to allow passing in additional aria attributes.
  def icon(fa)
    "<i class='fa-sharp fa-solid fa-#{fa}' aria-hidden='true''></i>"
  end

  # Formats location information for availability display.
  # Expects an array with three elements: [library name, location name, call number]
  def location(loc)
    "<strong>#{loc[0]}</strong> #{loc[1]} (#{loc[2]})"
  end
end
