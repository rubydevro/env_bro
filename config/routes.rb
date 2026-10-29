EnvBro::Engine.routes.draw do
  root "home#index"

  get "proposal/new" => "proposals#new", as: :new_proposal
  post "proposal" => "proposals#create", as: :proposal
  get "review/new" => "reviews#new", as: :new_review
  post "review" => "reviews#create", as: :review
  post "review/reveal" => "reviews#reveal", as: :reveal_review

  get "audit" => "audit#index", as: :audit
end
