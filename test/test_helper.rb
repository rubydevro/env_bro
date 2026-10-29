# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require_relative "../test/dummy/config/environment"
require "rails/test_help"

# Load the dummy schema into the test database on every run (cheap with SQLite).
ActiveRecord::Schema.verbose = false
load File.expand_path("dummy/db/schema.rb", __dir__)
# The boot hook may have read the table before the schema was reloaded.
EnvBro::AuditEvent.reset_column_information

class ActiveSupport::TestCase
  # config/credentials/test.yml.enc in the dummy app.
  def environment
    EnvBro::Environment.current
  end

  # A valid credentials file encrypted with some other key (e.g. another environment's).
  def foreign_cipher_text(yaml = { "x" => "1" }.to_yaml)
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "other.key"), ActiveSupport::EncryptedFile.generate_key)
      EnvBro::EncryptedBlob.new(content_path: File.join(dir, "other.yml.enc"), key_path: File.join(dir, "other.key"),
        env_key: "ENV_BRO_UNSET_KEY", raise_if_missing_key: true).encrypt_string(yaml)
    end
  end

  # Runs the block as if the app had booted with this credentials file deployed.
  def with_deployed_file(cipher_text)
    Dir.mktmpdir do |dir|
      FileUtils.cp(environment.key_path, File.join(dir, "test.key"))
      File.binwrite(File.join(dir, "test.yml.enc"), cipher_text)
      deployed = EnvBro::Environment.new(name: "test", content_path: File.join(dir, "test.yml.enc"),
        key_path: File.join(dir, "test.key"), env_key: "ENV_BRO_UNSET_KEY")
      with_current_environment(deployed) { yield }
    end
  end

  def with_current_environment(env)
    EnvBro::Environment.singleton_class.alias_method :original_current, :current
    EnvBro::Environment.define_singleton_method(:current) { env }
    yield
  ensure
    EnvBro::Environment.singleton_class.alias_method :current, :original_current
  end

  def audit_entries
    EnvBro::AuditEvent.recent.to_a
  end
end

class ActionDispatch::IntegrationTest
  def sign_in_as(role)
    post "/role", params: { role: role }
  end

  def upload(cipher_text, filename = "test.yml.enc")
    file = Tempfile.new([ "env_bro", ".enc" ])
    file.binmode
    file.write(cipher_text)
    file.rewind
    Rack::Test::UploadedFile.new(file.path, "application/octet-stream", original_filename: filename)
  end

  # new_keys: [{ key:, secret_value: }], edits: [{ key:, secret_value: }] or [{ key:, remove: "1" }]
  def propose(new_keys: [], edits: [])
    indexed = ->(rows) { rows.each_with_index.to_h { |row, i| [ i.to_s, row ] } }
    post "/admin/env/proposal", params: { new_keys: indexed.(new_keys), edits: indexed.(edits) }
  end
end
