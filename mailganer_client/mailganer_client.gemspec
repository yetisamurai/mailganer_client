# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = "mailganer_client"
  spec.version = "0.1.0"
  spec.authors       = ["Твое имя"]
  spec.email         = ["your@email.com"]

  spec.summary       = "Ruby client for Mailganer API"
  spec.description   = "Full Ruby wrapper for Mailganer email API, FBL, stop-list, statistics."
  spec.homepage      = "https://github.com/yourusername/mailganer_client"
  spec.license       = "MIT"

  spec.files         = ["lib/mailganer_client.rb"]
  spec.required_ruby_version = ">= 2.7"
  spec.add_dependency "json"
  spec.add_dependency "net-http"
end
