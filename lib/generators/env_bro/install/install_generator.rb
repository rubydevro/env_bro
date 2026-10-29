require "rails/generators"

module EnvBro
  module Generators
    # bin/rails generate env_bro:install
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Adds the EnvBro initializer, mounts the engine and copies its migrations."

      class_option :mount_path, type: :string, default: "/admin/env", desc: "Where to mount EnvBro"

      def copy_initializer
        copy_file "env_bro.rb", "config/initializers/env_bro.rb"
      end

      def mount_engine
        routes = File.join(destination_root, "config/routes.rb")
        if File.exist?(routes) && File.read(routes).include?("EnvBro::Engine")
          say_status :skip, "EnvBro::Engine is already mounted", :yellow
        else
          route %(mount EnvBro::Engine => "#{options[:mount_path]}")
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
            3. Visit #{options[:mount_path]}
        TEXT
      end
    end
  end
end
