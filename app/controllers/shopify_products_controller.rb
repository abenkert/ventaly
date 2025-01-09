class ShopifyProductsController < AuthenticatedController
  layout 'authenticated'

  def index
    shopify_session = current_shopify_session

    client = ShopifyAPI::Clients::Graphql::Admin.new(session: shopify_session)
    after_cursor = params[:after]
    before_cursor = params[:before]

    # Determine the pagination direction
    if before_cursor.present?
      pagination_params = { last: 10, before: before_cursor }
    else
      pagination_params = { first: 10, after: after_cursor }
    end

    query = <<~QUERY
      query($first: Int, $last: Int, $after: String, $before: String) {
        products(first: $first, last: $last, after: $after, before: $before) {
          edges {
            cursor
            node {
              id
              title
              description
              variants(first: 1) {
                edges {
                  node {
                    price
                    inventoryQuantity
                  }
                }
              }
            }
          }
          pageInfo {
            hasNextPage
            hasPreviousPage
            endCursor
            startCursor
          }
        }
      }
    QUERY

    response = client.query(query: query, variables: pagination_params)
    @products = response.body["data"]["products"]["edges"].map { |edge| edge["node"] }
    pp @products.first
    @page_info = response.body["data"]["products"]["pageInfo"]
  end
end
