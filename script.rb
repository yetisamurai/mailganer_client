require "mailganer_client"
require 'base64'

MailganerClient.configure do |config|
  config.api_key = ""
  config.smtp_login = ""
  config.api_key_web_portal = ""
end

client = MailganerClient.new

# response = client.send_email(
#   to: "rocker-ru@mail.ru",
#   from: "info@mysite.com",
#   subject: "Hello!",
#   body: "Your message goes here"
# )

# puts response


puts client.get_fbl_report_by_date(date_from: "2020-01-01", date_to: "2026-01-01")
# file_path = File.expand_path("test-image.jpg", __dir__)

# response = client.send_email_smtp_v1(
#     type: 'body',
#     to: "rocker-ru@mail.ru",
#     subject: "subject",
#     params:  {
#       name: 'Test name'
#     },
#     body: "Hello, {{name}}",
#     from: "info@saveme.su",
#     name_from: "Sender name info@saveme.su",
#     attach_files: [
#         {
#           name: File.basename(file_path),
#           filebody: Base64.strict_encode64(File.read(file_path))
#         }
#       ]
#     )

# puts response