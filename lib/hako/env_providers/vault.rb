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
        @dry_run = false
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
        if @dry_run
          resolve_only_keys(variables)
        else
          resolve(variables)
        end
      end

      def validatable?
        true
      end

      def validate!
        @validate = true
      end

      private

      def resolve_only_keys(variables)
        env = {}
        @http.start do
          variables.each do |key|
            path = Pathname.new('/v1/secret').join(@directory).join(key)
            req = Net::HTTP::Get.new("#{path.parent}?list=true")
            req['X-Vault-Token'] = ENV['VAULT_TOKEN']
            res = @http.request(req)
            case res.code
            when '200'
              path = Pathname.new(key).parent
              JSON.parse(res.body)['data']['keys'].each do |vault_key|
                env[path.join(vault_key).to_s] = "[secret value]"
              end
            when '404'
              nil
            else
              raise Error.new("Vault HTTP Error: #{res.code}: #{res.body}")
            end
          end
        end
        env
      end

      def resolve(variables)
        env = {}
        @http.start do
          variables.each do |key|
            req = Net::HTTP::Get.new("/v1/secret/#{@directory}/#{key}")
            req['X-Vault-Token'] = ENV['VAULT_TOKEN']
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
            req = Net::HTTP::Get.new("/v1/secret/#{@directory}/#{parent_dir}?list=true")
            req['X-Vault-Token'] = ENV['VAULT_TOKEN']
            res = @http.request(req)
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

      # @param [Array<String>] variables
      # @return [Array<String>]
      def parent_directories_for(variables)
        # XXX: URI module cannot join relative URIs
        base_uri = URI.parse("https://dummy/")
        variables.map do |variable|
          (base_uri + variable + '.').request_uri.sub(%r{\A/}, '')
        end.uniq
      end
    end
  end
end
