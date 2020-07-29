require 'spec_helper'
require 'nypl_log_formatter'
require 'webmock/rspec'
require 'aws-sdk-kms'

require_relative '../lib/errors'

ENV['LOG_LEVEL'] ||= 'info'
ENV['SIERRA_API_BASE_URL'] = 'https://example.com/iii/'
ENV['SIERRA_OAUTH_ID'] = Base64.strict_encode64 'fake-client'
ENV['SIERRA_OAUTH_SECRET'] = Base64.strict_encode64 'fake-secret'
ENV['SIERRA_OAUTH_URL'] = 'https://example.com/oauth'

ENV['PLATFORM_API_BASE_URL'] = 'https://example.com/api/v0.1/'
ENV['NYPL_OAUTH_URL'] = 'https://example.com/'
ENV['NYPL_OAUTH_ID'] = Base64.strict_encode64 'fake-client'
ENV['NYPL_OAUTH_SECRET'] = Base64.strict_encode64 'fake-secret'
ENV['APP_ENV'] = 'test'

ENV['EDD_EMAIL_SENDER'] = 'on-site-edd@nypl.org'
ENV['LIB_ANSWERS_EMAIL_SASB'] = Base64.strict_encode64 'user@example.com'

$logger = NyplLogFormatter.new(STDOUT, level: ENV['LOG_LEVEL'] || 'info')

Aws.config[:kms] = {
  stub_responses: {
    decrypt: {
      plaintext: 'decrypted'
    }
  }
}

Aws.config[:ses] = {
  stub_responses: {
    send_email: {
      message_id: "EXAMPLE78603177f-7a5433e7-8edb-42ae-af10-f0181f34d6ee-000000"
    }
  }
}

##
# Utility for temporarily swapping ENV values (and restoring them)
#
# Usage:
#   ENV['ENV_KEY_1'] = 'original value'
#   use_env({ 'ENV_KEY_1' => 'temporary value'}) do
#     # Now operating in a context where ENV['ENV_KEY_1'] === 'temporary value'
#   end
#   # Now operating in a context where ENV['ENV_KEY_1'] === 'original value'
def use_env(hash)
  previous_values = hash.keys.inject({}) { |h, k| h[k] = ENV[k]; h }
  hash.each { |(k, v)| ENV[k] = v }
  begin
    yield
  ensure
    previous_values.each { |(k, v)| ENV[k] = v }
  end
end
