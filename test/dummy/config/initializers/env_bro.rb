# EnvBro manages this environment's credentials (config/credentials/development.yml.enc
# when running in development). The sample keys sit in config/credentials/*.key.
EnvBro.configure do |config|
  config.can_create = ->(user) { user.can?(:create) }
  config.can_update = ->(user) { user.can?(:update) }
  config.can_destroy = ->(user) { user.can?(:destroy) }
  config.can_review = ->(user) { user.can?(:review) }
  config.can_reveal = ->(user) { user.can?(:reveal) }
end
