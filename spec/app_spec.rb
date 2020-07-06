require 'spec_helper'

require_relative '../app'

describe :app, :type => :controller do
  before do
    $logger = NyplLogFormatter.new(STDOUT, level: ENV['LOG_LEVEL'] || 'info')
  end

  describe :parse_body do
    it 'parses empty body' do
      expect(parse_body(nil)).to eq({})
      expect(parse_body({})).to eq({})
    end

    it 'parses plain json body' do
      expect(parse_body({ 'body' => '{ "key1": "value2" }' })).to include({ "key1" => "value2" })
    end

    it 'parses base64 encoded json body' do
      expect(parse_body({ 'body' => '{ "key1": "value2" }', 'bodyIsBase64Encoded' => true })).to include({ "key1" => "value2" })
    end
  end

  describe :handle_event do
    before(:each) do
      KmsClient.aws_kms_client.stub_responses(:decrypt, -> (context) {
        # "Decrypt" by subbing "encrypted" with "decrypted" in string:
        { plaintext: context.params[:ciphertext_blob].gsub('encrypted', 'decrypted') }
      })

      stub_request(:post, "#{ENV['SIERRA_OAUTH_URL']}").to_return(status: 200, body: '{ "access_token": "fake-access-token" }')

      stub_request(:post, "#{ENV['SIERRA_API_BASE_URL']}patrons/56789/holds/requests")
        .to_return(body: '', status: 201)
    end

    it 'responds to /docs/patron with 200 and swagger doc' do
      response = handle_event(
        event: {
          "path" => '/docs/on-site-hold-requests',
          "httpMethod" => 'GET'
        },
        context: {}
      )

      expect(response[:statusCode]).to eq(200)
      expect(response[:body]).to be_a(String)
      expect(JSON.parse(response[:body])).to be_a(Hash)
      expect(JSON.parse(response[:body])['paths']).to be_a(Hash)
    end

    it 'responds to POST on-site-hold-requests with 201' do
      response = handle_event(
        event: {
          "path" => '/api/v0.1/on-site-hold-requests',
          "httpMethod" => 'POST',
          "body" => '{ "record": 12345, "patron": 56789 }'
        },
        context: {}
      )

      expect(response[:statusCode]).to eq(201)
      expect(response[:body]).to be_a(String)
      expect(JSON.parse(response[:body])).to be_a(Hash)
      expect(JSON.parse(response[:body])['statusCode']).to eq(201)
    end
  end
end
