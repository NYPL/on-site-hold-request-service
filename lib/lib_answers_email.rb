require "erb"
require "aws-sdk-ses"

class LibAnswersEmail
  EMAIL_ENCODING = "UTF-8"
  EMAIL_SENDER = 'on-site-hold-request-service@nypl.org'

  def initialize(on_site_hold_request)
    @hold_request = on_site_hold_request
  end

  def initialize_email_data
    @email_data = {
      "Patron Information" => {
        "Patron Name" => @hold_request.patron.names.join('; '),
        "Patron Email" => @hold_request.patron.emails.join('; '),
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
        "EDD Pick-up Location" => @hold_request.pickup_location,
        "Volume Number" =>  @hold_request.doc_delivery_data['volume'],
        "Date" => @hold_request.doc_delivery_data['date'],
        "Page Numbers" => "#{@hold_request.doc_delivery_data['startPage']} - #{@hold_request.doc_delivery_data['endPage']}",
        "Additional Notes or Instructions" => @hold_request.doc_delivery_data['requestNotes']
      }
    }
  end

  def destination_email
    # FIXME: This is waiting on a real mapping:
    case @hold_request.item.location_code[(0...2)]
    when 'ma'
      ENV['LIB_ANSWERS_DEFAULT_DESTINATION_EMAIL']
    end
  end

  def body(which = :html)
    initialize_email_data if @email_data.nil?

    erb = ERB.new(File.read("./email/lib_answers_email.#{which}.erb")).result binding
  end

  def send
    ses = Aws::SES::Client.new(region: 'us-east-1')

    if destination_email.nil? || destination_email.empty?
      $logger.debug "Destination email unknown. Aborting LibAnswers email."
      return
    end

    # Try to send the email.
    begin
      # Provide the contents of the email.
      resp = ses.send_email({
        destination: {
          to_addresses: [
            destination_email
          ],
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
            data: 'EDD Hold Request'
          },
        },
        source: EMAIL_SENDER
      })
      $logger.debug "Email sent to #{destination_email}"

    rescue Aws::SES::Errors::ServiceError => error
      $logger.error "Email not sent. Error message: #{error}"
    end
  end

  def self.create(on_site_hold_request)
    self.new(on_site_hold_request).send
  end
end
