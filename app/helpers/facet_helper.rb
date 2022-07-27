module FacetHelper
  def add_facet(query, facet, term)
    new_query = query.clone
    new_query[:page] = 1
    new_query[facet.to_sym] = term
    new_query
  end

  def nice_labels
    {
      'contentFormat' => t('search.facet.content_formats'),
      'contentType' => t('search.facet.content_types'),
      'contributors' => t('search.facet.contributors'),
      'languages' => t('search.facet.languages'),
      'literaryForm' => t('search.facet.literary_forms'),
      'source' => t('search.facet.sources'),
      'subjects' => t('search.facet.subjects')
    }
  end

  def remove_facet(query, facet)
    new_query = query.clone
    new_query[:page] = 1
    new_query.delete facet.to_sym
    new_query
  end
end
