Rails.application.routes.draw do
  root "home#index"
  post "role" => "home#role", as: :role
  # BroHub mounts EnvBro under /bro_hub/env_bro ...
  mount BroHub::Engine => "/bro_hub"
  # ... and a host that mounted it directly (EnvBro 0.1.x) keeps working.
  mount EnvBro::Engine => "/admin/env"
end
