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

  ##
  # Attempt to
  #   1) Create hold in Sierra, and..
  #      if hold created successfully and it's an EDD request
  #   2) place EDD request in LibAnswers
  def create
    create_sierra_hold
    create_libanswers_job if is_edd?
    self
  end

  ##
  # Is the request an EDD request?
  def is_edd?
    ! @data.dig('docDeliveryData', 'emailAddress').nil?
  end

  ##
  # Pluck edd email
  def edd_email
    @data.dig('docDeliveryData', 'emailAddress')
  end

  ##
  # Is the custom EDD email given different from the patron email?
  def edd_email_differs_from_patron_email?
    return false unless is_edd?

    edd_email != patron.emails.first
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

  ##
  # Get location code for EDD pickup location based on item holding location
  def pickup_location
    if is_edd?
      # Determine pickup location by holding location for item
      case item.location_code[(0...2)]
      when 'ma'
        'maedd'
      when 'my'
        'myedd'
      when 'sc'
        'scedd'
      end
    else
      @data['pickupLocation']
    end
  end

  ##
  # Attempt to create hold in Sierra
  #
  # Will raise:
  #  - SierraRecordUnavailableError if hold can not be placed due to
  #    'not available' Sierra response
  #  - SierraHoldAlreadyCreated if hold has already been created
  #
  # Will return nil on success
  def create_sierra_hold
    patron_id = @data['patron']

    hold = {
      'recordType' => 'i',
      'recordNumber' => @data['record'],
      'pickupLocation' => pickup_location,
      'note' => 'Onsite EDD Shared Request'
    }
    # TODO: Sierra complains about json formatting if `neededBy` doesn't match
    # "ISO 8601 format (yyyy-MM-dd)", so we should reduce precision of
    # `neededBy` when time info is included.
    # For now, we'll just disable it because it's not set to anything
    # meaningful right now.
    # hold['neededBy'] = @data['neededBy'] unless @data['neededBy'].nil?

    # See https://sandbox.iii.com/iii/sierra-api/swagger/index.html#!/patrons/Place_a_new_hold_request_post_24
    $logger.debug "self.sierra_client.post \"patrons/#{patron_id}/holds/requests\", #{hold.to_json}"
    response = self.class.sierra_client.post "patrons/#{patron_id}/holds/requests", hold
    $logger.debug "self.sierra_client.post response: #{response.code} #{response.body}"

    if response.error?
      if response.body && response.body['description'].include?('This record is not available')
        # Failed due to mysterious "This record is not available" error
        raise SierraRecordUnavailableError, "Item unavailable in Sierra for patron #{patron_id}, item #{@data['record']}, pickup #{pickup_location}: #{response.code}: #{response.body}"
      elsif response.body && response.body['description'].include?('Request denied - already on hold for or checked out to you.')
        # Failed due to hold already existing for this patron
        raise SierraHoldAlreadyCreatedError, "Hold already created in Sierra for patron #{patron_id}, item #{@data['record']}, pickup #{pickup_location}: #{response.code}: #{response.body}"
      end
      raise SierraError, "Error placing Sierra hold for patron #{patron_id}, item #{@data['record']}, pickup #{pickup_location}: #{response.code}: #{response.body}"
    end
  end

  ##
  # Attempt to queue EDD job in LibAnswers
  #
  # Uncaught InternalError if error sending email via SES
  def create_libanswers_job
    return unless is_edd?

    LibAnswersEmail.create self
  end

  ##
  # Create new OnSiteHoldRequest
  #
  # Will raise:
  #  - ParameterError if Sierra reports item 'not available'
  #  - SierraHoldAlreadyCreatedError if hold already placed
  #  - SierraError if Sierra reports any other error
  #
  # Otherwise returns new OnSiteHoldRequest instance
  def self.create(params = {})
    [ 'patron', 'record' ].each do |param|
      # Ensure set
      raise ParameterError, "#{param} is required" unless params[param]
      # Ensure numeric:
      raise ParameterError, "#{param} isn't numeric" unless params[param].to_i.to_s == params[param].to_s
    end

    data = params.merge({
      'record' => params['record'].to_i,
      'patron' => params['patron'].to_i
    })

    begin
      self.new(data).create
    rescue SierraRecordUnavailableError => e
      raise ParameterError, "Item not available: #{data['record']}"
    rescue SierraError => e
      raise InternalError, "Internal error: Unspecified error placing hold"
    end
  end

  ##
  # Create a SierraApiClient instance
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
