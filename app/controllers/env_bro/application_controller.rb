module EnvBro
  class ApplicationController < EnvBro.config.parent_controller.constantize
    include BroHub::Layout
    bro_hub_section :env_bro

    protect_from_forgery with: :exception

    before_action :env_bro_require_ssl
    before_action :env_bro_no_store
    before_action { @environment = Environment.current }

    helper_method :env_bro_user, :env_bro_can?

    rescue_from EnvBro::Forbidden, with: :env_bro_forbidden

    private
      def env_bro_user
        return @env_bro_user if defined?(@env_bro_user)
        @env_bro_user = EnvBro.config.current_user.call(self)
      end

      # BroHub shows this name in the top bar, so it must be the same person EnvBro authorizes.
      def bro_hub_user
        env_bro_user
      end

      # permission: :create, :update, :destroy, :review or :reveal (higher ones include
      # lower ones), or :propose for "any of create, update, destroy".
      def env_bro_can?(permission)
        EnvBro.config.allows?(env_bro_user, permission)
      end

      def env_bro_authorize!(permission)
        raise EnvBro::Forbidden unless env_bro_can?(permission)
      end

      # The server needs this environment's key to do anything with the file.
      def env_bro_require_ready
        render "env_bro/shared/not_ready", status: :service_unavailable unless @environment.ready?
      end

      def env_bro_require_ssl
        return unless EnvBro.config.require_ssl
        head :forbidden unless request.ssl?
      end

      # Pages may show secret values: keep them out of browser and proxy caches.
      def env_bro_no_store
        response.headers["Cache-Control"] = "no-store"
        response.headers["Pragma"] = "no-cache"
      end

      def env_bro_forbidden
        render "env_bro/shared/forbidden", status: :forbidden
      end
  end
end
