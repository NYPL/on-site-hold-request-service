require_relative '../lib/on_site_hold_request'

describe LibAnswersEmail do
  before(:each) do
    stub_request(:post, "#{ENV['NYPL_OAUTH_URL']}oauth/token")
      .to_return(status: 200, body: '{ "access_token": "fake-access-token" }')

    stub_request(:get, "#{ENV['PLATFORM_API_BASE_URL']}items/sierra-nypl/10857004")
      .to_return(body: File.read('./spec/fixtures/item-10857004.json'))
    stub_request(:get, "#{ENV['PLATFORM_API_BASE_URL']}patrons/12345")
      .to_return(body: File.read('./spec/fixtures/patron-12345.json'))
    stub_request(:get, "#{ENV['PLATFORM_API_BASE_URL']}bibs/sierra-nypl/14468362")
      .to_return(body: File.read('./spec/fixtures/bib-14468362.json'))

    stub_request(:post, "#{ENV['SIERRA_API_BASE_URL']}patrons/12345/holds/requests")
      .to_return(body: '', status: 201)
  end

  describe 'body(:text)' do
    email = nil

    before(:each) do
      data = {
        "record" => 10857004,
        "patron" => 12345,
        "docDeliveryData" => {
          "date" => "date...",
          "emailAddress" => "user@example.com",
          "chapterTitle" => "Chapter One",
          "startPage" => "100",
          "endPage" => "150",
          "author" => "Anonymous",
          "issue" => "Summer 2017",
          "volume" => "159",
          "requestNotes" => "..."
        }
      }
      hold_request = OnSiteHoldRequest.new(data)
      email = LibAnswersEmail.new(hold_request)
    end

    it 'includes patron name' do
      expect(email.body(:text)).to include('Patron Name: McNameName, Namey')
    end

    it 'includes patron barcode' do
      expect(email.body(:text)).to include('Patron Barcode: 12345678901234')
    end

    it 'includes item barcode' do
      expect(email.body(:text)).to include('Item Barcode: 33433110638107')
    end

    it 'includes item call number' do
      expect(email.body(:text)).to include('Call Number: JFE 00-4013')
    end

    it 'includes EDD pickup location' do
      expect(email.body(:text)).to include('EDD Pick-up Location: mab')
    end

    it 'includes patron-supplied email' do
      expect(email.body(:text)).to include('Email: user@example.com')
    end

    it 'includes patron chapter/article title' do
      expect(email.body(:text)).to include('Chapter/Article Title: Chapter One')
    end
  end
end
