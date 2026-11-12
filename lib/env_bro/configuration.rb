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
    #   can_create  - propose new keys
    #   can_update  - propose new values for existing keys
    #   can_destroy - propose removing keys
    #   can_review  - upload a proposed file and see which keys changed (values masked)
    #   can_reveal  - reveal the actual values in a review diff (every reveal is audited)
    #
    # Any of them gets a user into the propose page (which only offers what they may do).
    # Higher permissions include the lower ones, so you don't have to repeat yourself:
    # review includes create, update and destroy; reveal includes everything.
    attr_accessor :can_create, :can_update, :can_destroy, :can_review, :can_reveal

    PERMISSIONS = %i[create update destroy review reveal].freeze

    # Permissions that also grant the key.
    IMPLIED_BY = {
      create: %i[review reveal],
      update: %i[review reveal],
      destroy: %i[review reveal],
      review: %i[reveal],
      reveal: []
    }.freeze

    # Shorthand: grant create, update and destroy with one check.
    def can_propose=(check)
      @can_create = @can_update = @can_destroy = check
    end

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
      @can_create = ->(_user) { false }
      @can_update = ->(_user) { false }
      @can_destroy = ->(_user) { false }
      @can_review = ->(_user) { false }
      @can_reveal = ->(_user) { false }
      @require_ssl = defined?(Rails) && Rails.env.production?
      @metadata_key = "env_bro"
      @max_upload_bytes = 1024 * 1024
      @track_deployments = true
    end

    # Does the user hold this permission, directly or through a higher one?
    # :propose means any of create, update or destroy.
    def allows?(user, permission)
      return false if user.nil?
      return %i[create update destroy].any? { |p| allows?(user, p) } if permission == :propose
      raise ArgumentError, "Unknown permission #{permission.inspect}" unless PERMISSIONS.include?(permission)

      [ permission, *IMPLIED_BY.fetch(permission) ].any? { |p| !!public_send(:"can_#{p}").call(user) }
    end
  end
end
