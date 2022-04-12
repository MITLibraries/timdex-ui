Rails.application.routes.draw do
  root "basic_search#index"

  get 'results', to: 'basic_search#results'
end
