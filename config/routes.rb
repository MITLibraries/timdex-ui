Rails.application.routes.draw do
  root "basic_search#index"

  get 'analyze', to: 'tacos#analyze'

  get 'libkey', to: 'thirdiron#libkey'
  get 'browzine', to: 'thirdiron#browzine'

  get 'record/(:id)',
      to: 'record#view',
      as: 'record',
      :constraints => { :id => /[0-z\.\-\_~\(\)]+/ }
  get 'results', to: 'search#results'
  get 'style-guide', to: 'static#style_guide'

  get 'boolpref', to: 'static#boolpref'

  get 'robots.txt', to: 'robots#robots'
end
