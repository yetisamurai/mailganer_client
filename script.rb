require "mailganer_client"

client = MailganerClient.new(
  api_key: "",
  smtp_login: "",
  api_key_web_portal: ""
)

puts client.get_fbl_report_by_date(date_from: "2020-01-01", date_to: "2026-01-01")
