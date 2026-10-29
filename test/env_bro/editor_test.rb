require "test_helper"

class EnvBro::EditorTest < ActiveSupport::TestCase
  test "applies changes and returns a file the environment key can read" do
    result = EnvBro::Editor.new(environment).apply([
      { action: "set", key: "stripe.secret_key", value: "sk_live_new" },
      { action: "set", key: "github.token", value: " ghp_x \n" },
      { action: "delete", key: "sendgrid_api_key" }
    ], author: "dev@example.com")

    assert_equal "test.yml.enc", result.filename
    updated = environment.decrypt(result.cipher_text)
    assert_equal "sk_live_new", updated.flatten["stripe.secret_key"]
    assert_equal "ghp_x", updated.flatten["github.token"]
    refute updated.key?("sendgrid_api_key")
    assert_equal environment.current_credentials.flatten["aws.access_key_id"], updated.flatten["aws.access_key_id"]
  end

  test "embeds metadata with the base digest and author" do
    result = EnvBro::Editor.new(environment).apply([ { key: "x", value: "1" } ], author: "dev@example.com")
    meta = environment.decrypt(result.cipher_text).metadata

    assert_equal EnvBro::Environment.digest(environment.current_cipher_text), meta["base_digest"]
    assert_equal "dev@example.com", meta["proposed_by"]
    assert_equal [ "set x" ], meta["changes"]
  end

  test "never writes to the credentials file" do
    before = environment.current_cipher_text
    EnvBro::Editor.new(environment).apply([ { key: "x", value: "1" } ], author: "a")
    assert_equal before, environment.current_cipher_text
  end

  test "keeps multi-line values and normalizes CRLF" do
    result = EnvBro::Editor.new(environment).apply([ { key: "pem", value: "line1\r\nline2\r\n" } ], author: "a")
    assert_equal "line1\nline2", environment.decrypt(result.cipher_text).flatten["pem"]
  end

  test "ignores completely blank rows" do
    result = EnvBro::Editor.new(environment).apply([ { key: "x", value: "1" }, { action: "set", key: "", value: "" } ], author: "a")
    assert_equal 1, result.changes.size
  end

  test "validates changes" do
    editor = EnvBro::Editor.new(environment)
    assert_raises(EnvBro::InvalidChange) { editor.apply([], author: "a") }
    assert_raises(EnvBro::InvalidChange) { editor.apply([ { key: "x", value: "  " } ], author: "a") }
    assert_raises(EnvBro::InvalidChange) { editor.apply([ { action: "drop", key: "x", value: "1" } ], author: "a") }
    assert_raises(EnvBro::InvalidChange) { editor.apply([ { key: "x", value: "1" }, { key: "x", value: "2" } ], author: "a") }
    assert_raises(EnvBro::InvalidChange) { editor.apply([ { key: "env_bro.base_digest", value: "1" } ], author: "a") }
    assert_raises(EnvBro::InvalidChange) { editor.apply([ { action: "delete", key: "missing" } ], author: "a") }
  end

  test "a file encrypted with another key cannot be decrypted" do
    assert_raises(EnvBro::DecryptionError) { environment.decrypt(foreign_cipher_text) }
    assert_raises(EnvBro::DecryptionError) { environment.decrypt("garbage") }
  end
end
