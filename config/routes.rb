Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :universities, only: [ :index, :show ], param: :slug
      resources :games, only: [ :index ]
      get "games/:year/:term/:team0/:team1/:round", to: "games#show",
        constraints: { year: /\d{4}/, term: /spring|autumn/, round: /\d+/ }
      get "seasons", to: "seasons#index"
      get "seasons/:year/:term", to: "seasons#show", constraints: { year: /\d{4}/, term: /spring|autumn/ }
      get "seasons/:year/:term/standings", to: "seasons#standings", constraints: { year: /\d{4}/, term: /spring|autumn/ }
      get "matchups/:team0_slug/:team1_slug", to: "matchups#show"
    end
  end

  get "api/docs", to: "api_docs#show", as: :api_docs

  get "og/site.png", to: "home#og_image", as: :site_og_image

  get "universities/og.png", to: "universities#og_image", as: :universities_og_image
  get "universities/:slug/og.png", to: "universities#show_og_image", as: :university_og_image
  resources :universities, only: [ :index, :show ], param: :slug

  get "games/og.png", to: "games#index_og_image", as: :games_index_og_image
  get "games/:team0_slug/:year/:term/og.png", to: "games#team_og_image", as: :team_season_og_image,
    constraints: { team0_slug: /[a-z]+/, year: /\d{4}/, term: /spring|autumn/ }
  get "games/:team0_slug/:year/:term", to: "games#browse", as: :team_season_browse,
    constraints: { team0_slug: /[a-z]+/, year: /\d{4}/, term: /spring|autumn/ }
  get "games/:team0_slug/og.png", to: "games#team_og_image", as: :team_og_image, constraints: { team0_slug: /[a-z]+/ }
  get "games/:team0_slug", to: "games#browse", as: :team_browse, constraints: { team0_slug: /[a-z]+/ }
  resources :games, only: [ :index ]

  resources :seasons, only: [ :index ]
  get "seasons/og.png", to: "seasons#index_og_image", as: :seasons_index_og_image
  get "seasons/:year/:term/og.png", to: "seasons#og_image", as: :season_og_image, constraints: { year: /\d{4}/, term: /spring|autumn/ }
  get "seasons/:year/:term", to: "seasons#show", as: :season, constraints: { year: /\d{4}/, term: /spring|autumn/ }
  get "seasons/:year/:term/standings", to: "seasons#standings", as: :standings_season, constraints: { year: /\d{4}/, term: /spring|autumn/ }
  get "matchups", to: "matchups#index", as: :matchups
  get "matchups/og.png", to: "matchups#index_og_image", as: :matchups_index_og_image
  get "matchups/:team0_slug/:team1_slug/:year/:term/:game_number/og.png", to: "games#og_image", as: :game_og_image,
    constraints: { year: /\d{4}/, term: /spring|autumn/, game_number: /\d+/ }
  get "matchups/:team0_slug/:team1_slug/:year/:term/:game_number", to: "matchups#show", as: :matchup_game,
    constraints: { year: /\d{4}/, term: /spring|autumn/, game_number: /\d+/ }
  get "matchups/:team0_slug/:team1_slug/:year/:term/og.png", to: "matchups#matchup_og_image", as: :matchup_season_og_image,
    constraints: { year: /\d{4}/, term: /spring|autumn/ }
  get "matchups/:team0_slug/:team1_slug/:year/:term", to: "matchups#show", as: :matchup_season,
    constraints: { year: /\d{4}/, term: /spring|autumn/ }
  get "matchups/:team0_slug/:team1_slug/:year/og.png", to: "matchups#matchup_og_image", as: :matchup_year_og_image,
    constraints: { year: /\d{4}/ }
  get "matchups/:team0_slug/:team1_slug/:year", to: "matchups#show", as: :matchup_year,
    constraints: { year: /\d{4}/ }
  get "matchups/:team0_slug/:team1_slug/og.png", to: "matchups#matchup_og_image", as: :matchup_og_image
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
