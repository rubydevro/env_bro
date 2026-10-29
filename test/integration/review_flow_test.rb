require "test_helper"

class ReviewFlowTest < ActionDispatch::IntegrationTest
  def proposed_file(changes = [ { key: "stripe.secret_key", value: "sk_live_rotated" }, { key: "new_key", value: "brand-new" } ])
    EnvBro::Editor.new(environment).apply(changes, author: "developer@example.com").cipher_text
  end

  test "developers cannot review" do
    sign_in_as "developer"
    get "/admin/env/review/new"
    assert_response :forbidden
  end

  test "admin uploads a proposal and sees masked changes" do
    sign_in_as "admin"
    post "/admin/env/review", params: { proposed_file: upload(proposed_file) }

    assert_response :success
    assert_includes response.body, "stripe.secret_key"
    assert_includes response.body, "new_key"
    assert_includes response.body, "Built on the same version"
    refute_includes response.body, "sk_live_rotated"
    refute_includes response.body, "brand-new"
    assert_equal "review_viewed", audit_entries.first.event
  end

  test "revealing a value shows it and is audited" do
    sign_in_as "admin"
    cipher = proposed_file
    post "/admin/env/review/reveal", params: { proposed_enc: cipher, reveal_key: "stripe.secret_key" }

    assert_response :success
    assert_includes response.body, "sk_live_rotated"
    assert_includes response.body, "sk_live_example"
    refute_includes response.body, "brand-new"

    entry = audit_entries.first
    assert_equal "values_revealed", entry.event
    assert_equal [ "stripe.secret_key" ], entry.details["keys"]
  end

  test "reveal all only reveals changed keys" do
    sign_in_as "admin"
    post "/admin/env/review/reveal", params: { proposed_enc: proposed_file, reveal_key: "*" }
    assert_includes response.body, "brand-new"
    refute_includes response.body, "AKIAPRODEXAMPLE"
  end

  test "warns when the proposal was built on another base" do
    sign_in_as "admin"
    other_base = proposed_file([ { key: "someone_else", value: "x" } ])
    post "/admin/env/review", params: { proposed_file: upload(proposed_file), base_file: upload(other_base) }

    assert_response :success
    assert_includes response.body, "Outdated base"
    assert_includes response.body, "someone_else"
  end

  test "warns when the file has no EnvBro metadata" do
    sign_in_as "admin"
    post "/admin/env/review", params: { proposed_file: upload(environment.current_cipher_text) }
    assert_includes response.body, "Not built with EnvBro"
  end

  test "a file encrypted with another key shows an error" do
    sign_in_as "admin"
    post "/admin/env/review", params: { proposed_file: upload(foreign_cipher_text) }
    assert_response :unprocessable_entity
    assert_includes response.body, "could not be decrypted"
  end

  test "audit log is visible to reviewers only" do
    sign_in_as "developer"
    get "/admin/env/audit"
    assert_response :forbidden

    sign_in_as "admin"
    get "/admin/env/audit"
    assert_response :success
  end

  test "audit log lists events newest first" do
    EnvBro::Audit.record(:proposal_created, user: User.new("developer"), changes: [ { action: "set", key: "old.key" } ])
    EnvBro::Audit.record(:proposal_created, user: User.new("developer"), changes: [ { action: "set", key: "new.key" } ])

    sign_in_as "admin"
    get "/admin/env/audit"
    assert_operator response.body.index("set new.key"), :<, response.body.index("set old.key")
  end

  test "audit log and review show whether a proposal is live" do
    result = EnvBro::Editor.new(environment).apply([ { key: "x", value: "1" } ], author: "developer@example.com")
    EnvBro::AuditEvent.create!(event: "proposal_created", environment: "test", user_label: "developer@example.com",
      proposal_token: result.proposal_token, file_digest: result.file_digest)

    sign_in_as "admin"
    post "/admin/env/review", params: { proposed_file: upload(result.cipher_text) }
    assert_select ".badge", text: "not deployed yet"

    with_deployed_file(result.cipher_text) { EnvBro::Deployments.track }
    get "/admin/env/audit"
    assert_select ".badge-ok", text: /live since/
    assert_select ".badge", text: "Proposal deployed"
  end
end
