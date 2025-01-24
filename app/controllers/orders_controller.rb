class OrdersController < AuthenticatedController
  layout 'authenticated'

  def index
    @shop = current_shop
    @orders = @shop.orders
    
    @orders = case params[:tab]
              when 'pending'
                @orders.where(status: 'pending')
              when 'shopify'
                @orders.where(platform: 'shopify')
              when 'ebay'
                @orders.where(platform: 'ebay')
              when 'completed'
                @orders.where(status: 'completed')
              else
                @orders
              end
            
    @tab = params[:tab] || 'all'
    @orders = @orders.order(order_placed_at: :desc).page(params[:page])
  end
end 