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
    if new_query[filter].present? && filter != 'source'
      new_query[filter] << term
      new_query[filter].uniq!
    else
      new_query[filter] = [term]
    end

    new_query
  end

  def nice_labels
    {
      'contentType' => 'Content types',
      'source' => 'Sources'
    }
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

  def filter_applied?(terms, term)
    return if terms.blank?

    terms.include?(term)
  end
end
