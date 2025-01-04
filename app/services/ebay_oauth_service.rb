require 'httparty'

class EbayOauthService
  include HTTParty
  base_uri 'https://api.ebay.com'
  BASE_URL = 'https://auth.ebay.com/oauth2/authorize'

  def initialize
    @client_id = ENV['EBAY_CLIENT_ID']
    @client_secret = ENV['EBAY_CLIENT_SECRET']
    @ru_name = ENV['EBAY_RUNAME']
    @scopes = 'https://api.ebay.com/oauth/api_scope'
  end

  def authorization_url()
    "#{BASE_URL}?client_id=#{@client_id}&response_type=code&redirect_uri=#{ERB::Util.url_encode(@ru_name)}&scope=#{@scopes}"
  end

  def fetch_access_token(auth_code)
    body = {
      grant_type: 'authorization_code',
      code: auth_code,
      redirect_uri: @ru_name # Ensure this is correctly set
    }
    auth = Base64.strict_encode64("#{@client_id}:#{@client_secret}")
  
    response = self.class.post('/identity/v1/oauth2/token', {
      headers: {
        'Authorization' => "Basic #{auth}",
        'Content-Type' => 'application/x-www-form-urlencoded'
      },
      body: URI.encode_www_form(body)
    })
  
    if response.code != 200
      Rails.logger.error("Failed to fetch access token: #{response.body}")
    end
  
    response
  end
end
