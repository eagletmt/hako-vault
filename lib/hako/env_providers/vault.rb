# frozen_string_literal: true
require 'hako/env_provider'
require 'net/http'
require 'uri'

module Hako
  module EnvProviders
    class Vault < EnvProvider
      REQUIRED_PARAMS = %w[addr directory].freeze

      # @param [Pathname] root_path
      # @param [Hash<String, Object>] options
      def initialize(_root_path, options)
        REQUIRED_PARAMS.each do |k|
          unless options[k]
            validation_error!("#{k} must be set")
          end
        end
        unless ENV['VAULT_TOKEN']
          validation_error!('Environment variable VAULT_TOKEN must be set')
        end

        uri = URI.parse(options['addr'])
        @http = Net::HTTP.new(uri.host, uri.port)
        if uri.scheme == 'https'
          @http.use_ssl = true
        end
        @directory = options['directory']
        @token = ENV['VAULT_TOKEN']
      end

      # @param [Array<String>] variables
      # @return [Hash<String, String>]
      def ask(variables)
        env = {}
        @http.start do
          variables.each do |key|
            req = Net::HTTP::Get.new("/v1/secret/#{@directory}/#{key}")
            req['X-Vault-Token'] = @token
            res = @http.request(req)
            case res.code
            when '200'
              env[key] = JSON.parse(res.body)['data']['value']
            when '404'
              nil
            else
              raise Error.new("Vault HTTP Error: #{res.code}: #{res.body}")
            end
          end
        end
        env
      end
    end
  end
end
