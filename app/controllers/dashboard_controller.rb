class DashboardController < AuthenticatedController

  def index
    @products = ShopifyAPI::Product.all(limit: 10)
  end
end
