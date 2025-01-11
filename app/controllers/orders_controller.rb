class OrdersController < AuthenticatedController
  layout 'authenticated'

  def index
    @tab = params[:tab] || 'all'
    @orders = Orders::OrderFetcher.new(current_shop, @tab).fetch
  end
end 