# Hako::EnvProviders::Vault

Provide variables from [Vault](https://www.vaultproject.io/) to [hako](https://github.com/eagletmt/hako)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'hako-vault'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install hako-vault

## Usage
### Store secret values to Vault

```
% export VAULT_ADDR=https://vault.example.com:8200
% echo -n '{"value": "Secret value from Vault"}' | vault write secret/hako/vault-sample/test_message -
```

### Configure hako application

Set `VAULT_TOKEN` environment variable when running hako commands.

```yaml
env:
  $providers:
    - type: vault
      addr: https://vault.example.com:8200
      directory: hako/vault-sample
  PORT: 3000
  MESSAGE: '#{test_message}'    # "Secret value from Vault" will be injected
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/hako-vault.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

