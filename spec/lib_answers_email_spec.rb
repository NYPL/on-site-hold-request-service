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

    stub_sendgrid
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
      expect(email.body(:text)).to include('EDD Pick-up Location: maedd')
    end

    it 'includes patron-supplied email' do
      expect(email.body(:text)).to include('Email: user@example.com')
    end

    it 'includes patron chapter/article title' do
      expect(email.body(:text)).to include('Chapter/Article Title: Chapter One')
    end

    it 'includes correct descriptive header' do
      # Trick the model into thinking it's operating against Production Sierra:
      use_env({ 'SIERRA_API_BASE_URL' => 'https://catalog.nypl.org/' }) do
        expected = 'A patron hold has been created in Production Sierra' +
          ' for an EDD request placed in Production SCC'
        expect(email.body(:text)).to include(expected)
      end

      # Trick the model into thinking it's operating against Sierra Test:
      use_env({ 'SIERRA_API_BASE_URL' => 'https://nypl-sierra-test.nypl.org/' }) do
        expected = 'A patron hold has been created in Sierra Test' +
          ' for an EDD request placed in SCC Training/QA'
        expect(email.email_header).to include(expected)
      end
    end
  end

  describe 'sendgrid_email_payload' do
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

    it 'builds relevant sendgrid payload' do
      payload = email.sendgrid_email_payload

      expect(payload[:reply_to]).to eq({ email: 'user@example.com' })
      expect(payload[:from]).to eq({ email: 'researchrequests@nypl.org' })
    end

    it 'does not include bcc if not configured in environment' do
      payload = email.sendgrid_email_payload

      expect(payload[:personalizations]).to be_a(Array)
      recips = payload[:personalizations].first
      expect(recips).to be_a(Hash)
      expect(recips[:to]).to be_a(Array)
      expect(recips[:to].first[:email]).to eq('decrypted-lib-answers-email-sasb')
      expect(recips[:bcc]).to be_nil
    end

    it 'includes bcc if configured in environment' do
      # This is an item in mal82, so SASB_BCC applies
      use_env({
        'LIB_ANSWERS_EMAIL_SASB_BCC' => Base64.encode64('encrypted-user@example.com')
      }) do
        payload = email.sendgrid_email_payload

        expect(payload[:personalizations]).to be_a(Array)
        recips = payload[:personalizations].first
        expect(recips).to be_a(Hash)
        expect(recips[:to]).to be_a(Array)
        expect(recips[:to].first[:email]).to eq('decrypted-lib-answers-email-sasb')
        expect(recips[:bcc]).to be_a(Array)
        expect(recips[:bcc].first[:email]).to eq('decrypted-user@example.com')
      end
    end
  end

  describe 'email for duplicate hold' do
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
      hold_request.duplicate = true
      email = LibAnswersEmail.new(hold_request)
    end

    it 'includes text indicating that hold is a duplicate' do
      expected = 'Patron has made this EDD request for an item they already have on hold.'
      expect(email.body(:html)).to include(expected)
    end
  end

  describe 'patron, item with missing fields'  do
    email = nil

    before(:each) do

      stub_request(:get, "#{ENV['PLATFORM_API_BASE_URL']}patrons/6789")
        .to_return(body: File.read('./spec/fixtures/patron-6789-no-data.json'))
      stub_request(:get, "#{ENV['PLATFORM_API_BASE_URL']}items/sierra-nypl/10857004999")
        .to_return(body: File.read('./spec/fixtures/item-10857004999-no-data.json'))

      data = {
        "record" => 10857004999,
        "patron" => 6789,
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

    it 'includes empty Email field' do
      expected = "Patron Email: \n"
      expect(email.body(:text)).to include(expected)
    end

    it 'includes empty Name field' do
      expected = "Patron Name: \n"
      expect(email.body(:text)).to include(expected)
    end

    it 'includes empty title field' do
      expected = "Item Title: \n"
      expect(email.body(:text)).to include(expected)
    end
  end
end
