Rails.application.routes.draw do
  root "basic_search#index"

  get 'analyze', to: 'tacos#analyze'

  get 'libkey', to: 'thirdiron#libkey'
  get 'browzine', to: 'thirdiron#browzine'
  get 'oa_work', to: 'openalex#work'

  get 'record/(:id)',
      to: 'record#view',
      as: 'record',
      :constraints => { :id => /[0-z\.\-\_~\(\)]+/ }
  get 'results', to: 'search#results'
  get 'turnstile', to: 'turnstile#show', as: 'turnstile'
  post 'turnstile/verify', to: 'turnstile#verify', as: 'turnstile_verify'
  get 'style-guide', to: 'static#style_guide'
  get 'about-natural-language-search', to: 'static#about_natural_language_search'

  get 'boolpref', to: 'static#boolpref'
  get 'natural_language_search_optin', to: 'static#natural_language_search_optin'

  get 'robots.txt', to: 'robots#robots'
end
