module ResultsHelper
  def results_summary(hits)
    hits.to_i >= 10_000 ? '10,000+ results' : "#{number_with_delimiter(hits)} results"
  end

  # https://mit.primo.exlibrisgroup.com/discovery/search?query=any,contains,breakfast%20of%20champions&tab=all&search_scope=bento_catalog&vid=01MIT_INST:MIT
  # https://mit.primo.exlibrisgroup.com/discovery/search?query=any,contains,breakfast%20of%20champions&tab=all&search_scope=cdi&vid=01MIT_INST:MIT
  def search_primo_link
    base_url = ENV.fetch('MIT_PRIMO_URL') + '/discovery/search?'
    base_url + search_primo_params
  end

  def search_primo_params
    URI.encode_www_form({
                          query: "any,contains,#{params[:q]}",
                          tab: 'all',
                          search_scope: 'all',
                          vid: ENV.fetch('PRIMO_VID')
                        })
  end

  # https://archivesspace.mit.edu/search?op%5B%5D=&q%5B%5D=minutes
  # https://archivesspace.mit.edu/search?utf8=✓&op%5B%5D=&q%5B%5D=minutes&limit=&field%5B%5D=&from_year%5B%5D=&to_year%5B%5D=&commit=Search
  # https://archivesspace.mit.edu/search?utf8=✓&op%5B%5D=&q%5B%5D=minutes&limit=&field%5B%5D=&from_year%5B%5D=&to_year%5B%5D=&commit=Search
  def search_aspace_link
    aspace_params = URI.encode_www_form({
                                          'q[]': params[:q],
                                          utf8: '✓',
                                          'op[]': ''
                                        })

    'https://archivesspace.mit.edu/search?' + aspace_params
  end

  def search_worldcat_link
    worldcat_params = URI.encode_www_form({
                                            queryString: params[:q]
                                          })

    'https://mit.on.worldcat.org/search?' + worldcat_params
  end
end
