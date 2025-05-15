require_relative './spec_helper'
require_relative '../lib/bib'

describe Bib do
  before(:each) do
    stub_request(:post, "#{ENV['NYPL_OAUTH_URL']}oauth/token")
      .to_return(status: 200, body: '{ "access_token": "fake-access-token" }')

    stub_request(:get, "#{ENV['PLATFORM_API_BASE_URL']}bibs/sierra-nypl/14468362")
      .to_return(body: File.read('./spec/fixtures/bib-14468362.json'))
  end

  it 'instantiates a Bib by id' do
    expect(Bib.by_id('sierra-nypl', 14468362)).to be_a(Bib)
  end

  it 'extracts author' do
    expect(Bib.by_id('sierra-nypl', 14468362).author).to eq("Walton, Hanes, Jr., 1941-2013.")
  end

  it 'extracts title' do
    expect(Bib.by_id('sierra-nypl', 14468362).title).to eq("Reelection : William Jefferson Clinton as a native-son presidential candidate")
  end

  it 'extracts standard_number' do
    expect(Bib.by_id('sierra-nypl', 14468362).standard_number).to eq('fake-standard-number')
  end
end
