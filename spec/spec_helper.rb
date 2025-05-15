require 'nypl_log_formatter'
require 'webmock/rspec'
require 'aws-sdk-kms'
require 'dotenv'

require_relative '../lib/errors'
require_relative '../lib/kms_client'

Dotenv.load('config/test.env')

$logger = NyplLogFormatter.new(STDOUT, level: ENV['LOG_LEVEL'] || 'info')

KmsClient.aws_kms_client.stub_responses(:decrypt, -> (context) {
  # "Decrypt" by subbing "encrypted" with "decrypted" in string:
  { plaintext: context.params[:ciphertext_blob].gsub('encrypted', 'decrypted') }
})

Aws.config[:ses] = {
  stub_responses: {
    send_email: {
      message_id: "EXAMPLE78603177f-7a5433e7-8edb-42ae-af10-f0181f34d6ee-000000"
    }
  }
}

def stub_sendgrid
  stub_request(:post, "https://api.sendgrid.com/v3/mail/send")
    .to_return(status: 200, body: "", headers: {})
end

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
