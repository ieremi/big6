Rails.application.routes.draw do
  resources :universities, only: [ :index ]

  get "games/:team0_slug/:year/:term", to: "games#browse", as: :team_season_browse,
    constraints: { team0_slug: /[a-z]+/, year: /\d{4}/, term: /spring|autumn/ }
  get "games/:team0_slug", to: "games#browse", as: :team_browse, constraints: { team0_slug: /[a-z]+/ }
  resources :games, only: [ :index ]

  resources :seasons, only: [ :index ]
  get "seasons/:year/:term", to: "seasons#show", as: :season, constraints: { year: /\d{4}/, term: /spring|autumn/ }
  get "seasons/:year/:term/standings", to: "seasons#standings", as: :standings_season, constraints: { year: /\d{4}/, term: /spring|autumn/ }
  get "matchups", to: "matchups#index", as: :matchups
  get "matchups/:team0_slug/:team1_slug/:year/:term/:game_number/og.png", to: "games#og_image", as: :game_og_image,
    constraints: { year: /\d{4}/, term: /spring|autumn/, game_number: /\d+/ }
  get "matchups/:team0_slug/:team1_slug/:year/:term/:game_number", to: "matchups#show", as: :matchup_game,
    constraints: { year: /\d{4}/, term: /spring|autumn/, game_number: /\d+/ }
  get "matchups/:team0_slug/:team1_slug/:year/:term", to: "matchups#show", as: :matchup_season,
    constraints: { year: /\d{4}/, term: /spring|autumn/ }
  get "matchups/:team0_slug/:team1_slug/:year", to: "matchups#show", as: :matchup_year,
    constraints: { year: /\d{4}/ }
  get "matchups/:team0_slug/:team1_slug", to: "matchups#show", as: :matchup
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "home#index"
end
