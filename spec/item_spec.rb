require_relative '../lib/item'

describe Item do
  before(:each) do
    stub_request(:post, "#{ENV['NYPL_OAUTH_URL']}oauth/token")
      .to_return(status: 200, body: '{ "access_token": "fake-access-token" }')

    stub_request(:get, "#{ENV['PLATFORM_API_BASE_URL']}items/sierra-nypl/10857004")
      .to_return(body: File.read('./spec/fixtures/item-10857004.json'))
    stub_request(:get, "#{ENV['PLATFORM_API_BASE_URL']}bibs/sierra-nypl/14468362")
      .to_return(body: File.read('./spec/fixtures/bib-14468362.json'))
  end

  it 'instantiates an item by id' do
    expect(Item.by_id('sierra-nypl', 10857004)).to be_a(Item)
    expect(Item.by_id('sierra-nypl', 10857004).id).to eq("10857004")
  end
  
  it 'extracts barcode' do
    expect(Item.by_id('sierra-nypl', 10857004).barcode).to eq('33433110638107')
  end

  it 'extracts location code' do
    expect(Item.by_id('sierra-nypl', 10857004).location_code).to eq('mal82')
  end

  it 'extracts item_type' do
    expect(Item.by_id('sierra-nypl', 10857004).item_type).to eq('55 (book, limited circ, MaRLI)')
  end

  it 'extracts call_number' do
    expect(Item.by_id('sierra-nypl', 10857004).call_number).to eq('JFE 00-4013')
  end

  it 'extracts staff_call_number' do
    expect(Item.by_id('sierra-nypl', 10857004).call_number).to eq('JFE 00-4013')
  end

  it 'fetches bib' do
    expect(Item.by_id('sierra-nypl', 10857004).bibs).to be_a(Array)
    expect(Item.by_id('sierra-nypl', 10857004).bibs.first).to be_a(Bib)
    expect(Item.by_id('sierra-nypl', 10857004).bibs.first.title).to eq("Reelection : William Jefferson Clinton as a native-son presidential candidate")
  end
end
