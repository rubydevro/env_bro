# EnvBro lets people propose changes to this environment's encrypted credentials
# without holding the key.
EnvBro.configure do |config|
  # Who may do what. Each lambda gets the signed in user (nil when signed out).
  # Everything is denied until you change these.
  config.can_propose = ->(user) { false } # e.g. user&.developer?
  config.can_review = ->(user) { false }  # e.g. user&.admin?
  config.can_reveal = ->(user) { false }  # see actual values in a review (audited)

  # How EnvBro finds the signed in user. Engine controllers inherit from
  # parent_controller, so its authentication (before_actions) applies too.
  # config.parent_controller = "::ApplicationController"
  # config.current_user = ->(controller) { controller.send(:current_user) }
  # config.user_label = ->(user) { user.email }

  # Reject plain HTTP (secret values travel through the browser).
  # config.require_ssl = Rails.env.production?

  # Top-level credentials key holding proposal metadata. nil disables it, along
  # with the outdated-base warning and deployment tracking by proposal id.
  # config.metadata_key = "env_bro"

  # Record on boot when the running credentials came from an EnvBro proposal.
  # config.track_deployments = true
end
