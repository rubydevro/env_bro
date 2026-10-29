require "test_helper"

class EnvBro::DifferTest < ActiveSupport::TestCase
  def differ(old, new)
    EnvBro::Differ.new(EnvBro::Credentials.new(old), EnvBro::Credentials.new(new))
  end

  test "classifies added, changed, removed and unchanged keys" do
    d = differ(
      { "a" => "1", "b" => "2", "g" => { "c" => "3" } },
      { "a" => "1", "b" => "20", "g" => { "d" => "4" }, "env_bro" => { "base_digest" => "x" } }
    )
    statuses = d.entries.to_h { |e| [ e.key, e.status ] }
    assert_equal({ "g.d" => :added, "b" => :changed, "g.c" => :removed, "a" => :unchanged }, statuses)
    assert_equal %w[g.d b g.c], d.changes.map(&:key)
    assert_equal({ added: 1, changed: 1, removed: 1, unchanged: 1 }, d.counts)
  end

  test "base status uses the embedded digest" do
    d = differ({}, { "env_bro" => { "base_digest" => "abc" } })
    assert_equal :current, d.base_status("abc")
    assert_equal :stale, d.base_status("def")
    assert_equal :unknown, differ({}, {}).base_status("abc")
  end
end
