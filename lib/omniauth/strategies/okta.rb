# frozen_string_literal: true

require 'omniauth-oauth2'

module OmniAuth
  module Strategies
    class Okta < OmniAuth::Strategies::OAuth2
      DEFAULT_SCOPE = %[openid profile email].freeze

      option :name, 'okta'

      option :skip_jwt, false
      option :jwt_leeway, 60

      option :client_options, {
        site:          'https://your-org.okta.com',
        authorize_url: 'https://your-org.okta.com/oauth2/v1/authorize',
        token_url:     'https://your-org.okta.com/oauth2/v1/token',
        user_info_url: 'https://your-org.okta.com/oauth2/v1/userinfo',
        response_type: 'id_token'
      }

      option :auth_server_id, ''

      option :scope, DEFAULT_SCOPE

      uid { raw_info['sub'] }

      info do
        {
          name:       raw_info['name'],
          email:      raw_info['email'],
          first_name: raw_info['given_name'],
          last_name:  raw_info['family_name'],
          image:      raw_info['picture']
        }
      end

      extra do
        {}.tap do |hash|
          hash[:raw_info] = raw_info unless skip_info?
          if access_token
            hash[:id_token] = access_token.token
            if !options[:skip_jwt] && !access_token.token.nil?
              hash[:id_info] = validated_token(access_token.token)
            end
          end
        end
      end

      alias :oauth2_access_token :access_token

      def access_token
        if oauth2_access_token
          ::OAuth2::AccessToken.new(client, oauth2_access_token.token, {
            :refresh_token => oauth2_access_token.refresh_token,
            :expires_in    => oauth2_access_token.expires_in,
            :expires_at    => oauth2_access_token.expires_at
          })
        end
      end

      def raw_info
        unless options[:auth_server_id]&.end_with?('/')
          options[:auth_server_id] = options[:auth_server_id] + '/'
        end
        @_raw_info ||= access_token.get("/oauth2/#{options[:auth_server_id]}v1/userinfo").parsed || {}
      rescue ::Errno::ETIMEDOUT
        raise ::Timeout::Error
      end

      def request_phase
        super
      end

      def callback_phase
        super
      end

      def callback_url
        options[:redirect_uri] || (full_host + script_name + callback_path)
      end

      def validated_token(token)
        JWT.decode(token,
                   nil,
                   false,
                   verify_iss:        true,
                   iss:               options[:client_options][:site],
                   verify_aud:        true,
                   aud:               options[:client_options][:site],
                   verify_sub:        true,
                   verify_expiration: true,
                   verify_not_before: true,
                   verify_iat:        true,
                   verify_jti:        false,
                   leeway:            options[:jwt_leeway]
                   ).first
      end
    end
  end
end
