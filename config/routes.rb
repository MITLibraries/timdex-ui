Rails.application.routes.draw do
  mount Flipflop::Engine => "/flipflop"
  root "basic_search#index"

  get 'doi', to: 'fact#doi'
  get 'isbn', to: 'fact#isbn'
  get 'issn', to: 'fact#issn'
  get 'pmid', to: 'fact#pmid'

  get 'record/(:id)',
      to: 'record#view',
      as: 'record',
      :constraints => { :id => /[0-z\.\-\_~\(\)]+/ }
  get 'results', to: 'search#results'
  get 'style-guide', to: 'static#style_guide'

  get 'start', to: 'static#start'
end
