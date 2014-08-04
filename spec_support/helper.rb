require 'cadre/rspec'
require 'roadforest-testing'
require 'vcr'

RSpec.configure do |config|
  config.backtrace_exclusion_patterns = [
    %r{gems/rspec-core},
    %r{gems/rspec-expectations}
  ]
  config.run_all_when_everything_filtered = true
end

Dir['spec_support/extra/**/*.rb'].each do |file|
  require file
end

VCR.configure do |config|
  config.ignore_localhost = true
  config.cassette_library_dir = "vcr_cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!
end
