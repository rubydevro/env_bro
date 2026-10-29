class HomeController < ApplicationController
  def index
  end

  def role
    session[:role] = params[:role].presence
    redirect_to params[:return_to].presence || root_path
  end
end
