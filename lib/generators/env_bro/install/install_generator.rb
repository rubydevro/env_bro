require "rails/generators"
require "generators/bro_hub/installable"

module EnvBro
  module Generators
    # bin/rails generate env_bro:install
    class InstallGenerator < Rails::Generators::Base
      # BroHub first (one mount for all the Bro gems), then EnvBro itself.
      include BroHub::Generators::Installable

      source_root File.expand_path("templates", __dir__)

      desc "Sets up the BroHub dashboard, adds the EnvBro initializer and copies EnvBro's migrations."

      def copy_initializer
        copy_file "env_bro.rb", "config/initializers/env_bro.rb"
      end

      def copy_migrations
        rails_command "env_bro:install:migrations", inline: true
      end

      def next_steps
        say <<~TEXT

          EnvBro is installed. Next:
            1. bin/rails db:migrate
            2. Set who may propose, review and reveal in config/initializers/env_bro.rb
            3. Visit #{bro_hub_path}/env_bro (BroHub mounts EnvBro under its own path)
            4. Upgrading from EnvBro 0.1.x? Run `bin/rails g bro_hub:install --remove-direct-mounts`, or remove the old
               `mount EnvBro::Engine` line from config/routes.rb yourself. It keeps working until you do.
        TEXT
      end
    end
  end
end
