module EnvBro
  class HomeController < ApplicationController
    def index
      if env_bro_can?(:propose)
        redirect_to new_proposal_path
      elsif env_bro_can?(:review)
        redirect_to new_review_path
      else
        raise EnvBro::Forbidden
      end
    end
  end
end
