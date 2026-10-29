require "test_helper"

class EnvBro::CredentialsTest < ActiveSupport::TestCase
  def creds(data = { "a" => "1", "aws" => { "key" => "k", "secret" => "s" } })
    EnvBro::Credentials.new(data.deep_dup)
  end

  test "flattens nested keys with dots and hides metadata" do
    c = creds("a" => "1", "aws" => { "key" => "k" }, "env_bro" => { "base_digest" => "x" })
    assert_equal({ "a" => "1", "aws.key" => "k" }, c.flatten)
  end

  test "outline lists groups and keys in file order with depth, without metadata" do
    c = creds("b" => "1", "aws" => { "key" => "k", "s3" => { "bucket" => "x" } }, "a" => "2", "env_bro" => { "x" => "y" })
    lines = c.outline.map { |l| [ l.path, l.depth, l.group ] }
    assert_equal [
      [ "b", 0, false ], [ "aws", 0, true ], [ "aws.key", 1, false ], [ "aws.s3", 1, true ], [ "aws.s3.bucket", 2, false ], [ "a", 0, false ]
    ], lines
  end

  test "set updates an existing nested key in place" do
    c = creds
    c.set("aws.key", "new")
    assert_equal "new", c.data["aws"]["key"]
    assert_equal %w[a aws], c.data.keys
  end

  test "set creates missing groups" do
    c = creds
    c.set("stripe.webhook.secret", "w")
    assert_equal "w", c.data.dig("stripe", "webhook", "secret")
  end

  test "set refuses to turn a value into a group or a group into a value" do
    assert_raises(EnvBro::InvalidChange) { creds.set("a.b", "x") }
    assert_raises(EnvBro::InvalidChange) { creds.set("aws", "x") }
  end

  test "set works with symbol keys" do
    c = creds({ aws: { key: "k" } })
    c.set("aws.key", "new")
    assert_equal({ aws: { key: "new" } }, c.data)
  end

  test "delete removes a key and empty parents" do
    c = creds("a" => "1", "x" => { "y" => { "z" => "1" } })
    c.delete("x.y.z")
    assert_equal({ "a" => "1" }, c.data)
  end

  test "delete of a missing key raises" do
    assert_raises(EnvBro::InvalidChange) { creds.delete("nope") }
    assert_raises(EnvBro::InvalidChange) { creds.delete("a.b") }
  end

  test "rejects invalid key names" do
    [ "", "a..b", "a b", "a/b", ".a" ].each do |bad|
      assert_raises(EnvBro::InvalidChange, bad) { EnvBro::Credentials.split(bad) }
    end
  end

  test "round-trips through YAML" do
    c = creds("pem" => "-----BEGIN-----\nabc\n-----END-----", "n" => 3)
    assert_equal c.data, EnvBro::Credentials.parse(c.to_yaml).data
  end
end
