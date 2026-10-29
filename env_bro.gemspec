require_relative "lib/env_bro/version"

Gem::Specification.new do |spec|
  spec.name        = "env_bro"
  spec.version     = EnvBro::VERSION
  spec.authors     = [ "Ruby Dev SRL" ]
  spec.email       = [ "office@rubydev.ro" ]
  spec.summary     = "Propose changes to Rails encrypted credentials without holding the keys."
  spec.description = "A mountable Rails engine: team members with permission build a re-encrypted credentials file " \
                     "with their changes and open a PR; reviewers upload the file and see a masked diff."
  spec.homepage    = "https://www.rubydev.ro"
  spec.license     = "MIT"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["rubygems_mfa_required"] = "true"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/rubydevro/env_bro"
  spec.metadata["bug_tracker_uri"] = "https://github.com/rubydevro/env_bro/issues"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.required_ruby_version = ">= 3.2"
  spec.add_dependency "rails", ">= 7.1"
end
