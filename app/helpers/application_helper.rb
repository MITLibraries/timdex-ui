module ApplicationHelper
  def tacos_enabled?
    ENV.fetch('TACOS_URL', '').present?
  end
  module_function :tacos_enabled?

  def timdex_sources
    ENV.fetch('TIMDEX_SOURCES', timdex_source_defaults).split(',')
  end

  def timdex_source_defaults
    ['DSpace@MIT', 'Abdul Latif Jameel Poverty Action Lab Dataverse',
     'Woods Hole Open Access Server', 'Zenodo'].join(',')
  end

  def index_page_title
    ENV.fetch('PLATFORM_NAME', nil) ? "Search #{ENV.fetch('PLATFORM_NAME')} | MIT Libraries" : 'Search | MIT Libraries'
  end

  def results_page_title(query, character_limit = 50)
    return index_page_title unless query.present?

    ignored_terms = %i[page advanced geobox geodistance booleanType tab]
    terms = query.reject { |term| ignored_terms.include? term }.values.join(' ')
    terms = "#{terms.first(character_limit)}..." if terms.length > character_limit
    "#{terms} | #{page_title_base}"
  end

  def record_page_title(record, character_limit = 25)
    # Theoretically, every record should have a title, but just in case...
    return index_page_title unless record.present? && record['title'].present?

    title = if record['title'].length > character_limit
              "#{record['title'].first(character_limit)}..."
            else
              record['title']
            end

    "#{title} | #{page_title_base}"
  end

  private

  def page_title_base
    ENV.fetch('PLATFORM_NAME', nil) ? "#{ENV.fetch('PLATFORM_NAME')} | MIT Libraries" : 'MIT Libraries'
  end
end
