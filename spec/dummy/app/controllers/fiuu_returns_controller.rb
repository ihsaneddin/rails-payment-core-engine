class FiuuReturnsController < ApplicationController
  skip_before_action :verify_authenticity_token

  def show
    render plain: "Fiuu return received", status: :ok
  end
end
