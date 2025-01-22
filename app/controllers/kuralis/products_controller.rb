module Kuralis
  class ProductsController < AuthenticatedController
    layout 'authenticated'

    def index
      @products = current_shop.kuralis_products
                            .order(created_at: :desc)
                            .page(params[:page])
                            .per(25)
    end
  end
end
