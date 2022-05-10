Rails.application.routes.draw do
  root "basic_search#index"

  get 'record/(:id)',
      to: 'record#view',
      as: 'record',
      :constraints => { :id => /[0-z\.\-\_~\(\)]+/ }
  get 'results', to: 'basic_search#results'
end
