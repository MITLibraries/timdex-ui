Rails.application.routes.draw do
  root "basic_search#index"

  get 'advanced-search', to: 'advanced_search#index'

  get 'record/(:id)',
      to: 'record#view',
      as: 'record',
      :constraints => { :id => /[0-z\.\-\_~\(\)]+/ }
  get 'results', to: 'search#results'
  get 'style-guide', to: 'static#style_guide'
end
