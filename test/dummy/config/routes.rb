Rails.application.routes.draw do
  root "home#index"
  post "role" => "home#role", as: :role
  mount EnvBro::Engine => "/admin/env"
end
