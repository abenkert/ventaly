class ShopifyListingService
  def initialize(kuralis_product)
    @product = kuralis_product
    @shop = @product.shop
    @client = ShopifyAPI::Clients::Graphql::Admin.new(session: @shop.shopify_session)
  end

  def create_listing
    return false if @product.shopify_product.present?

    variables = {
      input: {
        title: @product.title,
        descriptionHtml: escape_html(@product.description),
        vendor: @shop.shopify_domain,
        status: "ACTIVE",
        productType: "",
        handle: @product.title.parameterize
      }
    }

    response = @client.query(
      query: build_create_product_mutation,
      variables: variables
    )

    if response.body['data'] && response.body['data']['productCreate']['product']
      shopify_product = response.body['data']['productCreate']['product']
      
      # Create the association
      @product.create_shopify_product!(
        shopify_product_id: shopify_product['id'].split('/').last,
        title: shopify_product['title'],
        status: shopify_product['status'],
        shop: @shop
      )

      # Now create variant and set images
      create_variant
      upload_images if @product.images.attached?
      
      true
    else
      errors = response.body['data']&.dig('productCreate', 'userErrors') || response.body['errors']
      Rails.logger.error "Failed to create Shopify product: #{errors.inspect}"
      false
    end
  rescue => e
    Rails.logger.error "Error creating Shopify product: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    false
  end

  private

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

  def create_variant
    mutation = <<~GQL
      mutation variantCreate($input: ProductVariantInput!) {
        productVariantCreate(input: $input) {
          variant {
            id
          }
          userErrors {
            field
            message
          }
        }
      }
    GQL

    variables = {
      input: {
        productId: @product.shopify_product.platform_product_id,
        price: @product.base_price.to_s,
        sku: @product.sku,
        inventoryQuantities: [{
          availableQuantity: @product.base_quantity || 0
        }]
      }
    }

    @client.query(
      query: mutation,
      variables: variables
    )
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
          productId: @product.shopify_product.platform_product_id,
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