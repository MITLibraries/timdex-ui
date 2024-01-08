Rails.application.routes.draw do
  root "basic_search#index"

  get 'analyze', to: 'tacos#analyze'

  get 'lookup', to: 'libkey#lookup'

  get 'out', to: 'record#out', as: "outbound"
  
  get 'record/(:id)',
      to: 'record#view',
      as: 'record',
      :constraints => { :id => /[0-z\.\-\_~\(\)]+/ }
  get 'results', to: 'search#results'
  get 'style-guide', to: 'static#style_guide'

  get 'boolpref', to: 'static#boolpref'

  mount Split::Dashboard, at: 'split'

  get 'robots.txt', to: 'robots#robots'
end
