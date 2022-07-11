module ApplicationHelper
  def timdex_sources
    ENV.fetch('TIMDEX_SOURCES', timdex_source_defaults).split(',')
  end

  def timdex_source_defaults
    ['DSpace@MIT', 'Abdul Latif Jameel Poverty Action Lab Dataverse',
     'Woods Hole Open Access Server', 'Zenodo'].join(',')
  end
end
