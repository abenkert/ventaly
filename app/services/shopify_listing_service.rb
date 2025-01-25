class ShopifyListingService
  def initialize(kuralis_product)
    @product = kuralis_product
    @shop = @product.shop
    @client = ShopifyAPI::Clients::Graphql::Admin.new(session: @shop.shopify_session)
  end

  def create_listing
    return false if @product.shopify_product.present?

    # First create the base product
    product_variables = {
      input: {
        title: @product.title,
        descriptionHtml: escape_html(@product.description),
        vendor: @shop.shopify_domain,
        status: "ACTIVE",
        productType: "",
        handle: @product.title.parameterize
      }
    }

    product_response = @client.query(
      query: build_create_product_mutation,
      variables: product_variables
    )
    pp product_response
    if product_response.body['data'] && product_response.body['data']['productCreate']['product']
      shopify_product = product_response.body['data']['productCreate']['product']
      
      # Then create the variant with a separate mutation
      variant_response = create_variant_for_product(shopify_product['id'])
      
      if variant_response && variant_response['variant']
        variant = variant_response['variant']
        
        @product.create_shopify_product!(
          platform_product_id: shopify_product['id'].split('/').last,
          platform_variant_id: variant['id'].split('/').last,
          title: shopify_product['title'],
          status: shopify_product['status'],
          shop: @shop
        )

        upload_images if @product.images.attached?
        true
      else
        variant_errors = variant_response.body['data']&.dig('variantCreate', 'userErrors') || variant_response.body['errors']
        Rails.logger.error "Failed to create Shopify variant: #{variant_errors.inspect}"
        false
      end
    else
      product_errors = product_response.body['data']&.dig('productCreate', 'userErrors') || product_response.body['errors']
      Rails.logger.error "Failed to create Shopify product: #{product_errors.inspect}"
      false
    end
  rescue => e
    Rails.logger.error "Error creating Shopify product: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    false
  end

  private

  def create_variant_for_product(product_id)
    mutation = <<~GQL
      mutation {
        productVariantsBulkCreate(input: {
          productId: "#{product_id}",
          variants: [{
            price: "#{@product.base_price}",
            sku: "#{@product.sku}",
            inventoryQuantities: [{
              availableQuantity: #{@product.quantity || 0},
              locationId: "#{@shop.default_location_id}"
            }]
          }]
        }) {
          variant {
            id
            price
            sku
          }
          userErrors {
            field
            message
          }
        }
      }
    GQL

    response = @client.query(query: mutation)
    
    if response.body['data'] && response.body['data']['productVariantCreate']
      response.body['data']['productVariantCreate']
    else
      Rails.logger.error "Variant creation failed: #{response.body['errors']&.inspect}"
      nil
    end
  end

  def build_create_product_mutation
    <<~GQL
      mutation productCreate($input: ProductInput!) {
        productCreate(input: $input) {
          product {
            id
            title
            status
          }
          userErrors {
            field
            message
          }
        }
      }
    GQL
  end

  def upload_images
    mutation = <<~GQL
      mutation productImageCreate($input: ProductImageInput!) {
        productImageCreate(input: $input) {
          image {
            id
          }
          userErrors {
            field
            message
          }
        }
      }
    GQL

    @product.images.each do |image|
      variables = {
        input: {
          productId: @product.shopify_product.shopify_product_id,
          altText: @product.title,
          src: generate_image_url(image)
        }
      }

      @client.query(
        query: mutation,
        variables: variables
      )
    end
  end

  def generate_image_url(image)
    if Rails.env.production?
      Rails.application.routes.url_helpers.url_for(image)
    else
      image.blob.url(expires_in: 1.hour)
    end
  end

  def escape_html(text)
    return "" unless text
    text.gsub('"', '\"').gsub("\n", '\n').gsub("\r", '')
  end
end 