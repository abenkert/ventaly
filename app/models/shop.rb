# frozen_string_literal: true

class Shop < ActiveRecord::Base
  include ShopifyApp::ShopSessionStorageWithScopes

  has_one :shopify_ebay_account, dependent: :destroy

  def api_version
    ShopifyApp.configuration.api_version
  end
end
