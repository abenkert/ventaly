class EbayController < ApplicationController
    def auth
      service = EbayOauthService.new
      redirect_to service.authorization_url, allow_other_host: true
    end
  
    def callback
      auth_code = params[:code]
      if auth_code.nil?
        render json: { error: 'Authorization code is missing' }, status: :bad_request
        return
      end

      service = EbayOauthService.new
      response = service.fetch_access_token(auth_code)

      if response.code == 200
        # Store the access token and use it for API requests
        access_token = response.parsed_response['access_token']
        render json: { access_token: access_token }
      else
        render json: { error: response.parsed_response }, status: :unprocessable_entity
      end
    end
  end
  