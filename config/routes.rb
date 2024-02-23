Rails.application.routes.draw do
  mount Flipflop::Engine => "/flipflop"
  root "basic_search#index"

  get 'doi', to: 'fact#doi'
  get 'isbn', to: 'fact#isbn'
  get 'issn', to: 'fact#issn'
  get 'pmid', to: 'fact#pmid'

  get 'internal', to: 'search#results', as: 'internal'

  get 'record/(:id)',
      to: 'record#view',
      as: 'record',
      :constraints => { :id => /[0-z\.\-\_~\(\)]+/ }
  get 'style-guide', to: 'static#style_guide'
  get 'results', to: 'static#results'
end
