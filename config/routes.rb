Rails.application.routes.draw do
  root "basic_search#index"

  scope "(:locale)", locale: /#{I18n.available_locales.join('|')}/ do
    get 'doi', to: 'fact#doi'
    get 'isbn', to: 'fact#isbn'
    get 'issn', to: 'fact#issn'
    get 'pmid', to: 'fact#pmid'

    get "record/(:id)",
        to: 'record#view',
        as: 'record',
        :constraints => { :id => /[0-z\.\-\_~\(\)]+/ }
    get 'results', to: 'search#results'
    get 'style-guide', to: 'static#style_guide'
  end
end
