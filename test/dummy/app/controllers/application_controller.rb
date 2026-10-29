class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  # Dummy-app shortcut: append ?as=developer (or viewer/admin) to any URL to switch user.
  before_action { session[:role] = params[:as].presence if params.key?(:as) }

  helper_method :current_user

  private
    def current_user
      User.for_role(session[:role])
    end
end
