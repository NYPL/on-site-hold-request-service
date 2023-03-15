require_relative '../lib/on_site_hold_request'

describe OnSiteHoldRequest do
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
    stub_request(:post, "#{ENV['SIERRA_API_BASE_URL']}patrons/56789/holds/requests")
      .to_return(
        body: JSON.generate({"description": "Request denied - already on hold for or checked out to you."}),
        headers: {"Content-Type": "application/json"},
        status: 400
      )

    stub_sendgrid
  end

  it 'instantiates an EDD OnSiteHoldRequest from params' do
    params = {
      "record" => "10857004",
      "patron" => "12345",
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
    hold_request = OnSiteHoldRequest.create params
    expect(hold_request).to be_a(OnSiteHoldRequest)
    expect(hold_request.patron).to be_a(NyplPatron)
    expect(hold_request.is_edd?).to eq(true)
    expect(hold_request.patron.id).to eq(12345)
    expect(hold_request.item).to be_a(Item)
    expect(hold_request.item.id).to eq("10857004")
    expect(hold_request.pickup_location).to eq("maedd")
  end

  it 'detects EDD email that differs from patron email' do
    params = {
      "record" => "10857004",
      "patron" => "12345",
      "docDeliveryData" => {
        "date" => "date...",
        "emailAddress" => "user@example.com"
      }
    }
    hold_request = OnSiteHoldRequest.create params
    expect(hold_request).to be_a(OnSiteHoldRequest)
    expect(hold_request.edd_email_differs_from_patron_email?).to eq(true)
  end

  it 'detects EDD email that matches patron email' do
    params = {
      "record" => "10857004",
      "patron" => "12345",
      "docDeliveryData" => {
        "date" => "date...",
        "emailAddress" => "example@example.com"
      }
    }
    hold_request = OnSiteHoldRequest.create params
    expect(hold_request).to be_a(OnSiteHoldRequest)
    expect(hold_request.edd_email_differs_from_patron_email?).to eq(false)
  end


  describe 'distinguishing edd and retrieval requests' do
    params_hold = {
      'requestType' => 'hold'
    }

    params_edd = {
      'requestType' => 'edd'
    }

    describe 'is_retrieval?' do
      it 'checks whether the requestType is \'hold\'' do
        expect(OnSiteHoldRequest.new(params_hold).is_retrieval?).to eq(true)
        expect(OnSiteHoldRequest.new(params_edd).is_retrieval?).to eq(false)
      end
    end

    describe 'create_sierra_hold' do
      it 'includes EDD note in case of retrieval request' do
        mock_sierra_client = double(nil)
        mock_response = double(nil)
        note =  nil
        allow(mock_response).to receive(:code).and_return nil
        allow(mock_response).to receive(:body).and_return nil
        allow(mock_response).to receive(:error?).and_return nil
        allow(OnSiteHoldRequest).to receive(:sierra_client).and_return mock_sierra_client
        allow(mock_sierra_client).to receive(:post) do |*args|
          note = args[1]["note"]
          mock_response
        end
        OnSiteHoldRequest.new(params_edd).create_sierra_hold
        expect(note).to eq("Onsite EDD Shared Request")
      end

      it 'does not include EDD note in case of non-retrieval request' do
        mock_sierra_client = double(nil)
        mock_response = double(nil)
        note =  nil
        allow(mock_response).to receive(:code).and_return nil
        allow(mock_response).to receive(:body).and_return nil
        allow(mock_response).to receive(:error?).and_return nil
        allow(OnSiteHoldRequest).to receive(:sierra_client).and_return mock_sierra_client
        allow(mock_sierra_client).to receive(:post) do |*args|
          note = args[1]["note"]
          mock_response
        end
        OnSiteHoldRequest.new(params_hold).create_sierra_hold
        expect(note).to eq(nil)
      end
    end

    describe 'create_libanswers_job' do
      it 'returns early in case of retrieval request' do
        allow(LibAnswersEmail).to receive(:create)
        expect(LibAnswersEmail).not_to receive(:create)
        OnSiteHoldRequest.new(params_hold).create_libanswers_job
      end

      it 'calls LibAnswersEmail for edd request' do
        allow(LibAnswersEmail).to receive(:create)
        expect(LibAnswersEmail).not_to receive(:create)
        OnSiteHoldRequest.new(params_edd).create_libanswers_job
      end
  end
  end
end
