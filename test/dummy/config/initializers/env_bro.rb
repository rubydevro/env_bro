# EnvBro manages this environment's credentials (config/credentials/development.yml.enc
# when running in development). The sample keys sit in config/credentials/*.key.
EnvBro.configure do |config|
  config.can_propose = ->(user) { user.developer? }
  config.can_review = ->(user) { user.admin? }
  config.can_reveal = ->(user) { user.admin? }
end
