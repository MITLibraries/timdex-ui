module FacetHelper
  def add_facet(query, facet, term)
    new_query = query.clone
    new_query[:page] = 1
    new_query[facet.to_sym] = term
    new_query
  end

  def nice_labels
    {
      'contentType' => 'Content types',
      'source' => 'Sources'
    }
  end

  def remove_facet(query, facet)
    new_query = query.clone
    new_query[:page] = 1
    new_query.delete facet.to_sym
    new_query
  end
end
