module Kuralis
  class ProductsController < AuthenticatedController
    layout 'authenticated'

    def index
      @products = current_shop.kuralis_products
    end
  end
end
