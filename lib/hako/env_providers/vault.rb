# frozen_string_literal: true
require 'hako/env_provider'
require 'json'
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
      end

      # @param [Array<String>] variables
      # @return [Hash<String, String>]
      def ask(variables)
        env = {}
        @http.start do
          variables.each do |key|
            res = get_with_retry("/v1/secret/#{@directory}/#{key}")
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

      # @return [Boolean]
      def can_ask_keys?
        true
      end

      # @param [Array<String>] variables
      # @return [Array<String>]
      def ask_keys(variables)
        keys = []
        @http.start do
          parent_directories_for(variables).each do |parent_dir|
            res = get_with_retry("/v1/secret/#{@directory}/#{parent_dir}?list=true")
            case res.code
            when '200'
              keys += JSON.parse(res.body)['data']['keys'].map { |key| "#{parent_dir}#{key}" }
            when '404'
              # Ignore
            else
              raise Error.new("Vault HTTP Error: #{res.code}: #{res.body}")
            end
          end
        end
        keys.select { |key| variables.include?(key) }
      end

      private

      # @param [Array<String>] variables
      # @return [Array<String>]
      def parent_directories_for(variables)
        # XXX: URI module cannot join relative URIs
        base_uri = URI.parse("https://dummy/")
        variables.map do |variable|
          (base_uri + variable + '.').request_uri.sub(%r{\A/}, '')
        end.uniq
      end

      # @param [String] path
      # @return [Net::HTTPResponse]
      def get_with_retry(path)
        last_error = nil
        10.times do |i|
          req = Net::HTTP::Get.new(path)
          req['X-Vault-Token'] = ENV['VAULT_TOKEN']
          res = @http.request(req)
          code = res.code.to_i
          if retryable_http_code?(code)
            Hako.logger.warn("Vault HTTP Error: #{res.code}: #{res.body}")
            last_error = res
            interval = 1.5**i
            Hako.logger.warn("Retrying after #{interval} seconds")
            sleep(interval)
          else
            return res
          end
        end
        raise Error.new("Vault HTTP Error: #{last_error.code}: #{last_error.body}")
      end

      def retryable_http_code?(code)
        code == 307 || (code >= 500 && code < 600)
      end
    end
  end
end
