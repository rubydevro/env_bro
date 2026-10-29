module EnvBro
  class Configuration
    # Controller the engine controllers inherit from. Inheriting from the host's
    # ApplicationController gives access to its authentication (current_user etc).
    attr_accessor :parent_controller

    # ->(controller) { ... } returning the signed in user, or nil.
    attr_accessor :current_user

    # ->(user) { ... } returning a short label for the audit log and file metadata.
    attr_accessor :user_label

    # Permission checks, each ->(user) { true/false }.
    #   can_propose - see key names, build a new encrypted file with changes
    #   can_review  - upload a proposed file and see which keys changed (values masked)
    #   can_reveal  - reveal the actual values in a review diff (every reveal is audited)
    attr_accessor :can_propose, :can_review, :can_reveal

    # Reject plain HTTP requests (secret values travel through the browser).
    attr_accessor :require_ssl

    # Top-level credentials key where EnvBro stores proposal metadata
    # (base file digest, author, time). Set to nil to disable.
    attr_accessor :metadata_key

    attr_accessor :max_upload_bytes

    # On boot, record when the running credentials file came from an EnvBro proposal.
    attr_accessor :track_deployments

    def initialize
      @parent_controller = "::ApplicationController"
      @current_user = ->(controller) { controller.respond_to?(:current_user, true) ? controller.send(:current_user) : nil }
      @user_label = ->(user) { user.respond_to?(:email) ? user.email : user.to_s }
      @can_propose = ->(_user) { false }
      @can_review = ->(_user) { false }
      @can_reveal = ->(_user) { false }
      @require_ssl = defined?(Rails) && Rails.env.production?
      @metadata_key = "env_bro"
      @max_upload_bytes = 1024 * 1024
      @track_deployments = true
    end
  end
end
