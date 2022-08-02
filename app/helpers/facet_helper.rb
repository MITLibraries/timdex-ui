module FacetHelper
  def add_facet(query, facet, term)
    new_query = query.deep_dup
    new_query[:page] = 1

    # source is being treated as single value in facet application
    # even though we allow OR-ing multiple sources via advanced search
    # This might feel somewhat odd, but until we get feedback from UX this
    # seems like the best solution as each record only has a single source
    # in the data so there will never be a case to apply multiple in an AND
    # which is all we support in facet application.
    if new_query[facet].present? && facet != 'source'
      new_query[facet] << term
      new_query[facet].uniq!
    else
      new_query[facet] = [term]
    end

    new_query
  end

  def nice_labels
    {
      'contentType' => 'Content types',
      'source' => 'Sources'
    }
  end

  def remove_facet(query, facet)
    new_query = query.deep_dup
    new_query[:page] = 1
    new_query.delete facet.to_sym
    new_query
  end
end
