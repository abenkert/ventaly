# frozen_string_literal: true

class Shop < ApplicationRecord
  include ShopifyApp::ShopSessionStorageWithScopes

  has_one :shopify_ebay_account, dependent: :destroy
  has_many :kuralis_products, dependent: :destroy

  def api_version
    ShopifyApp.configuration.api_version
  end
end
