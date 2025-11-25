# Mailganer Client

A simple Ruby client for the Mailganer API.\
Designed to make sending requests and integrating with the service
effortless.

## 🚀 Installation

Add this line to your application's Gemfile:

``` ruby
gem "mailganer-client"
```

Then install:

``` bash
bundle install
```

Or install it manually:

``` bash
gem install mailganer-client
```

## 📦 Usage

``` ruby
require "mailganer_client"

MailganerClient.configure do |config|
  config.api_key: "your-smtp-api-key",
  config.smtp_login: "xxx",
  config.api_key_web_portal: "your-web-portal-api-key"
end

client = MailganerClient.new

response = client.send_email(
  to: "user@example.com",
  from: "info@mysite.com",
  subject: "Hello!",
  body: "Your message goes here"
)

puts response
```

``` ruby

response = client.get_fbl_report_by_date(date_from: "2020-01-01", date_to: "2026-01-01")

puts response
```


``` ruby

response = client.send_email_smtp_v1(
    type: 'template',
    to: "test@test.com",
    subject: "subject",
    template_id: "template_id from mailganer web portal",
    params:  {
      name: 'Test name',
      unsubscribeUrl: ''
    },
    from: "from@mysite.com",
    name_from: "Sender name from@mysite.com"
  )

puts response
```


``` ruby

#file_path = Rails.root.join('app', 'javascript', 'src', 'public', 'img', 'test-image.jpg')
#file_path = File.expand_path("test-image.jpg", __dir__)
require 'base64'

response = client.send_email_smtp_v1(
    type: 'template',
    to: "test@test.com",
    subject: "subject",
    template_id: "template_id from mailganer web portal",
    params:  {
      name: 'Test name'
    },
    from: "from@mysite.com",
    body: "Hello, {{name}}",  
    name_from: "Sender name from@mysite.com",
    attach_files: [
        {
          name: File.basename("file_path"),
          filebody: Base64.strict_encode64(File.read("file_path"))
        }
      ]
    )

puts response
```

## ⚙️ Configuration

``` ruby
MailganerClient.configure do |config|
  config.api_key: "your-smtp-api-key",
  config.smtp_login: "xxx",
  config.api_key_web_portal: "your-web-portal-api-key"
end
```

```

## 🏗 Development

``` bash
git clone https://github.com/yetisamurai/mailganer_client.git
cd mailganer_client
```
