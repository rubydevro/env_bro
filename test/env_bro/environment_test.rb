require "test_helper"

class EnvBro::EnvironmentTest < ActiveSupport::TestCase
  def env_with(content_path: environment.content_path, key_path:)
    EnvBro::Environment.new(name: "test", content_path: content_path, key_path: key_path, env_key: "ENV_BRO_UNSET_KEY")
  end

  test "uses the running environment's credentials file, like Rails does" do
    assert_equal "test", environment.name
    assert_equal Rails.root.join("config/credentials/test.yml.enc"), environment.content_path
    assert_equal :ready, environment.status
  end

  test "wrong_key when the key can't decrypt the file" do
    Dir.mktmpdir do |dir|
      key = File.join(dir, "other.key")
      File.write(key, ActiveSupport::EncryptedFile.generate_key)
      assert_equal :wrong_key, env_with(key_path: key).status
    end
  end

  test "missing_key and missing_file" do
    assert_equal :missing_key, env_with(key_path: "/nonexistent.key").status
    assert_equal :missing_file, env_with(content_path: "/nonexistent.yml.enc", key_path: "/nonexistent.key").status
  end
end
