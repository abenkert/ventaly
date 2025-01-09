class OrdersController < AuthenticatedController
  layout 'authenticated'

  def index
    @tab = params[:tab] || 'all'
    @orders = [] # We'll implement order fetching later
  end
end 