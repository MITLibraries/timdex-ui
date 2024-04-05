module FilterHelper
  def add_filter(query, filter, term)
    new_query = query.deep_dup
    new_query[:page] = 1

    # source is being treated as single value in filter application
    # even though we allow OR-ing multiple sources via advanced search
    # This might feel somewhat odd, but until we get feedback from UX this
    # seems like the best solution as each record only has a single source
    # in the data so there will never be a case to apply multiple in an AND
    # which is all we support in filter application.
    if new_query[filter].present? && filter != :sourceFilter
      new_query[filter] << term
      new_query[filter].uniq!
    else
      new_query[filter] = [term]
    end

    new_query
  end

  def nice_labels
    {
      accessToFilesFilter: ENV.fetch('FILTER_ACCESS_TO_FILES', 'Access to files'),
      contentTypeFilter: ENV.fetch('FILTER_CONTENT_TYPE', 'Content type'),
      contributorsFilter: ENV.fetch('FILTER_CONTRIBUTOR', 'Contributor'),
      formatFilter: ENV.fetch('FILTER_FORMAT', 'Format'),
      languagesFilter: ENV.fetch('FILTER_LANGUAGE', 'Language'),
      literaryFormFilter: ENV.fetch('FILTER_LITERARY_FORM', 'Literary form'),
      placesFilter: ENV.fetch('FILTER_PLACE', 'Place'),
      sourceFilter: ENV.fetch('FILTER_SOURCE', 'Source'),
      subjectsFilter: ENV.fetch('FILTER_SUBJECT', 'Subject')
    }
  end

  def gdt_sources(value, category)
    return value if category != :sourceFilter

    return 'Non-MIT institutions' if value == 'opengeometadata gis resources'

    return 'MIT' if value == 'mit gis resources'

    value
  end

  def remove_filter(query, filter, term)
    new_query = query.deep_dup
    new_query[:page] = 1

    if new_query[filter].length > 1
      new_query[filter].delete(term) # If more than one term is filtered, we only delete the selected term
    else
      new_query.delete(filter) # If only one term is filtered, delete the entire filter from the query
    end

    new_query
  end

  def remove_all_filters(query)
    new_query = query.deep_dup
    new_query[:page] = 1

    applied_filters(query).each do |filter|
      filter.each_key { |filter_key| new_query.delete(filter_key) if new_query[filter_key].present? }
    end

    new_query
  end

  def filter_applied?(terms, term)
    return if terms.blank?

    terms.include?(term)
  end

  def applied_filters(query)
    filters = []
    query.map do |param, values|
      next unless param.to_s.include? 'Filter'

      values.each { |value| filters << { param => value } }
    end
    filters
  end
end
