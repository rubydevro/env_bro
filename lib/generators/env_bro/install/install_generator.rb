require "rails/generators"

module EnvBro
  module Generators
    # bin/rails generate env_bro:install
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Adds the EnvBro initializer, mounts the engine and copies its migrations."

      DEFAULT_MOUNT_PATH = "/admin/env"

      class_option :mount_path, type: :string,
        desc: "Where to mount EnvBro (asked interactively when omitted, default #{DEFAULT_MOUNT_PATH})"

      def copy_initializer
        copy_file "env_bro.rb", "config/initializers/env_bro.rb"
      end

      def mount_engine
        routes = File.join(destination_root, "config/routes.rb")
        if File.exist?(routes) && File.read(routes).include?("EnvBro::Engine")
          say_status :skip, "EnvBro::Engine is already mounted", :yellow
        else
          route %(mount EnvBro::Engine => "#{mount_path}")
        end
      end

      def copy_migrations
        rails_command "env_bro:install:migrations", inline: true
      end

      def next_steps
        say <<~TEXT

          EnvBro is installed. Next:
            1. bin/rails db:migrate
            2. Set who may propose, review and reveal in config/initializers/env_bro.rb
            3. Visit #{mount_path}
        TEXT
      end

      private
        # --mount-path wins; otherwise ask when someone is at the terminal.
        def mount_path
          @mount_path ||= begin
            path = options[:mount_path].presence
            path ||= ask("Where should EnvBro be mounted?", default: DEFAULT_MOUNT_PATH) if $stdin.tty?
            path = path.to_s.strip.presence || DEFAULT_MOUNT_PATH
            "/" + path.delete_prefix("/").delete_suffix("/")
          end
        end
    end
  end
end
