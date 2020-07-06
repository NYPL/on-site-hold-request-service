require_relative '../lib/nypl_patron'

describe NyplPatron do
  before(:each) do
    stub_request(:post, "#{ENV['NYPL_OAUTH_URL']}oauth/token")
      .to_return(status: 200, body: '{ "access_token": "fake-access-token" }')

    stub_request(:get, "#{ENV['PLATFORM_API_BASE_URL']}patrons/12345")
      .to_return(body: File.read('./spec/fixtures/patron-12345.json'))
  end

  it 'instantiates an NyplPatron by id' do
    expect(NyplPatron.by_id(12345)).to be_a(NyplPatron)
    expect(NyplPatron.by_id(12345).id).to eq(12345)
  end

  it 'extracts barcodes' do
    expect(NyplPatron.by_id(12345).barcodes).to be_a(Array)
    expect(NyplPatron.by_id(12345).barcodes.first).to eq("12345678901234")
  end

  it 'extracts names' do
    expect(NyplPatron.by_id(12345).names).to be_a(Array)
    expect(NyplPatron.by_id(12345).names.first).to eq("McNameName, Namey")
  end

  it 'extracts email' do
    expect(NyplPatron.by_id(12345).emails).to be_a(Array)
    expect(NyplPatron.by_id(12345).emails.first).to eq("example@example.com")
  end

  it 'extracts ptype' do
    expect(NyplPatron.by_id(12345).ptype).to eq("81")
  end
end
