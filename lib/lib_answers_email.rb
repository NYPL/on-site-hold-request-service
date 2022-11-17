require "erb"
require 'sendgrid-ruby'
include SendGrid

require_relative 'kms_client'
require_relative 'errors'
require_relative 'string_util'

class LibAnswersEmail
  EMAIL_ENCODING = "UTF-8"
  EMAIL_SENDER = 'researchrequests@nypl.org'

  @@_location_email_mapping = nil

  def initialize(on_site_hold_request)
    @hold_request = on_site_hold_request
  end

  ##
  # Initialize the data necessary to build the LibAnswers email
  def initialize_email_data
    # For date-time formatting, set TZ
    ENV['TZ'] = 'US/Eastern'

    @email_data = {
      "EDD Information" => {
        "Email" => @hold_request.doc_delivery_data['emailAddress'],
        "EDD Pick-up Location" => @hold_request.pickup_location,
        "Page Numbers" => "#{@hold_request.doc_delivery_data['startPage']} - #{@hold_request.doc_delivery_data['endPage']}",
        "Chapter/Article Title" =>  @hold_request.doc_delivery_data['chapterTitle'],
        "Author" =>  @hold_request.doc_delivery_data['author'],
        "Volume Number" =>  @hold_request.doc_delivery_data['volume'],
        "Issue" =>  @hold_request.doc_delivery_data['issue'],
        "Date" => @hold_request.doc_delivery_data['date'],
        "Additional Notes or Instructions" => @hold_request.doc_delivery_data['requestNotes'],
        "Requested On" => Time.new.strftime('%A %B %d, %I:%M%P ET')
      },
      "Patron Information" => {
        "Patron Name" => format(@hold_request.patron.names),
        "Patron Email" => format(@hold_request.patron.emails) +
        ( !@hold_request.patron.emails.nil? && @hold_request.edd_email_differs_from_patron_email? ? ' (Patron supplied a different email below.)' : ''),
        "Patron Barcode" => format(@hold_request.patron.barcodes),
        "Patron Ptype" => @hold_request.patron.ptype,
        "Patron ID" => @hold_request.patron.id
      },
      "Item Information" => {
        "Author" => format(@hold_request.item.bibs, :author),
        "Item Title" => format(@hold_request.item.bibs, :title),
        "Call Number" => @hold_request.item.call_number,
        "Staff Call Number" => @hold_request.item.staff_call_number,
        "Standard Number" => format(@hold_request.item.bibs, :standard_number),
        "Item Barcode" => @hold_request.item.barcode,
        "Item Type" => @hold_request.item.item_type,
        "Location Code" => @hold_request.item.location_code,
        "Bib ID" => format(@hold_request.item.bibs, :id),
        "Item ID" => @hold_request.item.id,
        "Research Catalog URL" => @hold_request.item.bibs
          .map { |bib| "https://#{rc_domain}/research/collections/shared-collection-catalog/bib/b#{bib.id}" }
          .join('; '),
        "Legacy Catalog URL" => @hold_request.item.bibs
          .map { |bib| "https://#{legacy_catalog_domain}/record=b#{bib.id}" }
          .join('; ')
      }
    }
    @duplicate = @hold_request.is_duplicate?
  end

  def email_header
    'A patron hold has been created in ' +
      (is_sierra_test? ? 'Sierra Test' : 'Production Sierra') +
      ' for an EDD request placed in ' +
      (is_sierra_test? ? 'SCC Training/QA' : 'Production SCC')
  end

  def duplicate_text
    return nil unless @hold_request.is_duplicate?
    'Patron has made this EDD request for an item they already have on hold.'
  end

  ##
  # Get relevant SCC domain
  def rc_domain
    is_sierra_test? ? ENV['RC_QA_DOMAIN'] : 'www.nypl.org'
  end

  ##
  # Get relevant catalog domain
  def legacy_catalog_domain
    is_sierra_test? ? 'nypl-sierra-test.nypl.org' : 'catalog.nypl.org'
  end

  ##
  # Returns true if the hold was created in Sierra Test
  def is_sierra_test?
    ENV['SIERRA_API_BASE_URL'].include? 'nypl-sierra-test.nypl.org'
  end

  ##
  # Get the LibAnswers email address appropriate for the item by location
  def destination_email
    email = nil

    case @hold_request.item.location_code[(0...2)]
    when 'ma'
      email = location_email_mapping['SASB']
    when 'my'
      email = location_email_mapping['LPA']
    when 'sc'
      email = location_email_mapping['SC']
    end

    if email.nil?
      $logger.debug "Could not determine LibAnswers email for item location #{@hold_request.item.location_code}"
      raise InternalError, "Error queueing EDD"
    end

    $logger.debug "LibAnswers email for #{@hold_request.item.location_code}: #{email}"
    email = ENV['DEVELOPMENT_LIB_ANSWERS_EMAIL'] if ENV['APP_ENV'] != 'production'

    email
  end

  ##
  # Get the optional BCC address to use when sending to official LibAnswers recip
  def bcc_emails
    emails = nil

    case @hold_request.item.location_code[(0...2)]
    when 'ma'
      emails = ENV['LIB_ANSWERS_EMAIL_SASB_BCC'] || ''
    when 'my'
      emails = ENV['LIB_ANSWERS_EMAIL_LPA_BCC'] || ''
    when 'sc'
      emails = ENV['LIB_ANSWERS_EMAIL_SC_BCC'] || ''
    end

    unless emails.empty?
      emails = KmsClient.new.decrypt emails

      $logger.debug "LibAnswers BCC for #{@hold_request.item.location_code}: #{emails}"

      emails = emails.split(',').map(&:strip)
    end

    emails
  end

  ##
  # Get a hash mapping location slugs ('SASB', 'LPA', 'SC') to LibAnswers email addresses
  def location_email_mapping
    return @@_location_email_mapping unless @@_location_email_mapping.nil?

    kms_client = KmsClient.new

    @@_location_email_mapping = ENV.keys
      .filter { |key| key.match?(/^LIB_ANSWERS_EMAIL_([A-Z]+)$/) }
      .map { |key| [key.sub('LIB_ANSWERS_EMAIL_', ''), kms_client.decrypt(ENV[key])] }
      .to_h
  end

  ##
  # Get email body in specified format (:html, :text)
  def body(which = :html)
    initialize_email_data if @email_data.nil?

    ERB.new(File.read("./email/lib_answers_email.#{which}.erb")).result binding
  end

  def subject
    format(@hold_request.item.bibs, :title).truncate(100)
  end

  ##
  # Attempt to send the email through SES
  #
  # Will raise InternalError if error sending email via SES
  def send
    request_body = sendgrid_email_payload

    sendgrid = SendGrid::API.new(api_key: KmsClient.new.decrypt(ENV['SENDGRID_API_KEY']))
    response = sendgrid.client.mail._('send').post(request_body: request_body)
    if response.status_code.nil? || response.status_code.to_i >= 300
      $logger.error "Failed to send LibAnswers email via Sendgrid: #{response.status_code} '#{response.body}'"
    end
  end

  def sendgrid_email_payload
    recip = destination_email
    if recip.nil? || recip.empty?
      $logger.debug "Destination email unknown. Aborting LibAnswers email."
      return
    end

    # See https://docs.sendgrid.com/api-reference/mail-send/mail-send#
    payload = {
      from: {
        email: EMAIL_SENDER
      },
      reply_to: {
        email: @hold_request.edd_email
      },
      personalizations: [
        {
          to: [
            { email: recip }
          ]
        }
      ],
      subject: subject,
      content: [
        {
          type: 'text/plain',
          value: body(:text)
        },
        {
          type: 'text/html',
          value: body(:html)
        }
      ]
    }
    unless bcc_emails.empty?
      payload[:personalizations].first << { bcc: bcc_emails.map { |email| { email: email } } }
    end

    payload
  end

  ##
  # Util for formatting values in email.
  #
  # Given a value, returns the value(s) as a string.
  #
  # If `pluck` given, extracts the named property from each value
  def format(val, pluck = nil)
    val = val.map(&pluck) if val.is_a?(Array) && !pluck.nil?
    val.is_a?(Array) ? val.join('; ') : val.to_s
  end

  ##
  # Attempt to create and send LibAnswers email
  #
  # Will raise InternalError if error sending email via SES
  #
  # Otherwise returns nil
  def self.create(on_site_hold_request)
    self.new(on_site_hold_request).send
  end
end
