require "erb"
require "aws-sdk-ses"

require_relative 'kms_client'
require_relative 'errors'
require_relative 'string_util'

class LibAnswersEmail
  EMAIL_ENCODING = "UTF-8"
  # TODO: Fix issue where @nypl.org are not deliverable from @nypl.org sender
  EMAIL_SENDER = 'no-reply@mylibrarynyc.org' # researchrequests@nypl.org'

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
      "Patron Information" => {
        "Patron Name" => @hold_request.patron.names.join('; '),
        "Patron Email" => @hold_request.patron.emails.join('; ') +
          ( @hold_request.edd_email_differs_from_patron_email? ? ' (Patron supplied a different email below.)' : ''),
        "Patron Barcode" => @hold_request.patron.barcodes.join('; '),
        "Patron Ptype" => @hold_request.patron.ptype,
        "Patron ID" => @hold_request.patron.id
      },
      "Item Information" => {
        "Author" => @hold_request.item.bibs.map(&:author).join('; '),
        "Item Title" => @hold_request.item.bibs.map(&:title).join('; '),
        "Call Number" => @hold_request.item.call_number,
        "Staff Call Number" => @hold_request.item.staff_call_number,
        "Standard Number" => @hold_request.item.bibs.map(&:standard_number).join('; '),
        "Item Barcode" => @hold_request.item.barcode,
        "Item Type" => @hold_request.item.item_type,
        "Location Code" => @hold_request.item.location_code,
        "Bib ID" => @hold_request.item.bibs.map(&:id).join('; '),
        "Item ID" => @hold_request.item.id,
        "SCC URL" => @hold_request.item.bibs
          .map { |bib| "https://www.nypl.org/research/collections/shared-collection-catalog/bib/b#{bib.id}" }
          .join('; '),
        "Catalog URL" => @hold_request.item.bibs
          .map { |bib| "https://catalog.nypl.org/record=b#{bib.id}" }
          .join('; ')
      },
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
      }
    }
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
  def bcc_email
    email = nil

    case @hold_request.item.location_code[(0...2)]
    when 'ma'
      email = ENV['LIB_ANSWERS_EMAIL_SASB_BCC']
    when 'my'
      email = ENV['LIB_ANSWERS_EMAIL_LPA_BCC']
    when 'sc'
      email = ENV['LIB_ANSWERS_EMAIL_SC_BCC']
    end

    $logger.debug "LibAnswers BCC for #{@hold_request.item.location_code}: #{email}"

    email
  end

  ##
  # Get a hash mapping location slugs ('SASB', 'LPA', 'SC') to LibAnswers email addresses
  def location_email_mapping
    return @@_location_email_mapping unless @@_location_email_mapping.nil?

    kms_client = KmsClient.new

    @@_location_email_mapping = ENV.keys
      .filter { |key| key.match? /^LIB_ANSWERS_EMAIL_([A-Z]+)$/ }
      .map { |key| [key.sub('LIB_ANSWERS_EMAIL_', ''), kms_client.decrypt(ENV[key])] }
      .to_h
  end

  ##
  # Get email body in specified format (:html, :text)
  def body(which = :html)
    initialize_email_data if @email_data.nil?

    erb = ERB.new(File.read("./email/lib_answers_email.#{which}.erb")).result binding
  end

  ##
  # Attempt to send the email through SES
  #
  # Will raise InternalError if error sending email via SES
  def send
    ses = Aws::SES::Client.new(region: 'us-east-1')

    recip = destination_email
    if recip.nil? || recip.empty?
      $logger.debug "Destination email unknown. Aborting LibAnswers email."
      return
    end

    # Build the email
    ses_data = {
      destination: {
        to_addresses: [
          recip
        ]
      },
      message: {
        body: {
          html: {
            charset: EMAIL_ENCODING,
            data: body(:html)
          },
          text: {
            charset: EMAIL_ENCODING,
            data: body(:text)
          },
        },
        subject: {
          charset: EMAIL_ENCODING,
          data: @hold_request.item.bibs.map(&:title).join('; ').truncate(100)
        },
      },
      source: EMAIL_SENDER,
      reply_to_addresses: [ @hold_request.edd_email ]
    }

    # Shall we BCC anyone?
    bcc = bcc_email
    ses_data[:destination][:bcc_addresses] = [bcc] if bcc

    begin
      # Send the email
      ses.send_email ses_data
      $logger.debug "Email sent to #{recip}#{bcc ? ", bcc #{bcc}" : ''}"

    rescue Aws::SES::Errors::ServiceError => error
      $logger.error "Email not sent. Error message: #{error}"
      raise InternalError, "Internal error: Issue queueing EDD"
    end
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
