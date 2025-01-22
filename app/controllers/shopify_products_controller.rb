class ShopifyProductsController < AuthenticatedController
  layout 'authenticated'

  def index
    @shop = current_shop
    @products = @shop.shopify_products
                          .order(created_at: :desc)
                          .page(params[:page])
                          .per(25)
  end
end
