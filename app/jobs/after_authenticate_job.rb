class AfterAuthenticateJob < ApplicationJob
  queue_as :default

  def perform(shop_domain)
    # Logic to handle after authentication
  end
end
