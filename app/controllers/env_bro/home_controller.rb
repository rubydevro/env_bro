module EnvBro
  class HomeController < ApplicationController
    before_action { raise EnvBro::Forbidden unless env_bro_can?(:propose) || env_bro_can?(:review) }

    def index
    end
  end
end
