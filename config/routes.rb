Rails.application.routes.draw do
  post "/challenge", to: "bot_challenge_page/bot_challenge_page#verify_challenge", as: :bot_detect_challenge
  mount Flipflop::Engine => "/flipflop"
  root "basic_search#index"

  get 'doi', to: 'fact#doi'
  get 'isbn', to: 'fact#isbn'
  get 'issn', to: 'fact#issn'
  get 'pmid', to: 'fact#pmid'

  get 'analyze', to: 'tacos#analyze'

  get 'record/(:id)',
      to: 'record#view',
      as: 'record',
      :constraints => { :id => /[0-z\.\-\_~\(\)]+/ }
  get 'results', to: 'search#results'
  get 'style-guide', to: 'static#style_guide'

  get 'boolpref', to: 'static#boolpref'
end
