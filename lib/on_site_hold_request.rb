require 'date'

require 'nypl_sierra_api_client'

require_relative 'kms_client'
require_relative 'errors'
require_relative 'lib_answers_email'
require_relative 'item'
require_relative 'nypl_patron'

class OnSiteHoldRequest
  @@_sierra_client = nil

  def initialize (data)
    @data = data
  end

  def create
    create_sierra_hold
    create_libanswers_job if is_edd?
    self
  end

  def is_edd?
    ! @data.dig('docDeliveryData', 'emailAddress').nil?
  end

  def doc_delivery_data
    @data['docDeliveryData']
  end

  def patron
    return @patron unless @patron.nil?

    @patron = NyplPatron.by_id @data['patron']
  end

  def item
    return @item unless @item.nil?

    @item = Item.by_id 'sierra-nypl', @data['record']
  end

  def pickup_location
    if is_edd?
      # Determine pickup location by holding location for item
      holding_location = item.location_code
      # TODO: need a way to determine correct EDD pickup location
      'mab'
    else
      @data['pickupLocation']
    end
  end

  def create_sierra_hold
    patron_id = @data['patron']

    hold = {
      'recordType' => 'i',
      'recordNumber' => @data['record'],
      'pickupLocation' => pickup_location
    }
    hold['neededBy'] = @data['neededBy'] unless @data['neededBy'].nil?
    hold['numberOfCopies'] = @data['numberOfCopies'] unless @data['numberOfCopies'].nil?

    # See https://sandbox.iii.com/iii/sierra-api/swagger/index.html#!/patrons/Place_a_new_hold_request_post_24
    $logger.debug "self.sierra_client.post \"patrons/#{patron_id}/holds/requests\", #{hold.to_json}"
    response = self.class.sierra_client.post "patrons/#{patron_id}/holds/requests", hold
    $logger.debug "self.sierra_client.post response: #{response.code} #{response.body}"
  end

  def create_libanswers_job
    return unless is_edd?

    LibAnswersEmail.create self
  end

  def self.create(params = {})
    raise ParameterError, 'record is required' unless params['record']
    raise ParameterError, 'patron is required' unless params['patron']

    self.new(params).create
  end

  def self.sierra_client
    if @@_sierra_client.nil?
      kms_client = KmsClient.new

      $logger.debug "Creating sierra_client"
      @@_sierra_client = SierraApiClient.new({
        base_url: ENV['SIERRA_API_BASE_URL'],
        oauth_url: ENV['SIERRA_OAUTH_URL'],
        client_id: kms_client.decrypt(ENV['SIERRA_OAUTH_ID']),
        client_secret: kms_client.decrypt(ENV['SIERRA_OAUTH_SECRET'])
      })
    end

    @@_sierra_client
  end
end
