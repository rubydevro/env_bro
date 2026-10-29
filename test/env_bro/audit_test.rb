require "test_helper"

class EnvBro::AuditTest < ActiveSupport::TestCase
  test "records an event with key names, the user label and the environment" do
    event = EnvBro::Audit.record(:values_revealed, user: User.new("admin"), keys: [ "a.b" ])

    assert event.persisted?
    assert_equal "admin@example.com", event.user_label
    assert_equal "test", event.environment
    assert_equal [ "a.b" ], event.keys
  end

  test "events are append-only" do
    event = EnvBro::Audit.record(:review_viewed, user: User.new("admin"))
    assert_raises(ActiveRecord::ReadOnlyRecord) { event.update!(user_label: "someone else") }
  end

  test "rejects unknown events" do
    assert_raises(ActiveRecord::RecordInvalid) { EnvBro::Audit.record(:nope, user: nil) }
  end
end
