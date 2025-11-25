# frozen_string_literal: true
require_relative "lib/mailganer_client/version"

Gem::Specification.new do |spec|
  spec.name          = "mailganer-client"
  spec.version       = MailganerClient::VERSION 
  spec.authors       = ["yetisamurai"]
  spec.email         = ["yetisamurai@proton.me"]

  spec.summary       = "Ruby client for Mailganer API"
  spec.description   = "Full Ruby wrapper for Mailganer email API, FBL, stop-list, statistics."
  spec.homepage      = "https://github.com/yetisamurai/mailganer_client"
  spec.license       = "CC0-1.0"

  spec.files         = Dir["lib/**/*.rb"]
  spec.require_paths = ["lib"]  
  spec.required_ruby_version = ">= 2.7"
  spec.add_dependency "json"
  spec.add_dependency "net-http"
  spec.extra_rdoc_files = ["README.md"]
  spec.has_rdoc = true
  spec.rdoc_options = ["--main", "README.md"]
end
