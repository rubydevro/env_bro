require "test_helper"

class ProposalFlowTest < ActionDispatch::IntegrationTest
  test "anonymous users and viewers are forbidden" do
    get "/admin/env"
    assert_response :forbidden

    sign_in_as "viewer"
    get "/admin/env/proposal/new"
    assert_response :forbidden
  end

  test "home redirects to the page the user can use" do
    sign_in_as "developer"
    get "/admin/env"
    assert_redirected_to "/admin/env/proposal/new"

    sign_in_as "admin"
    get "/admin/env"
    assert_redirected_to "/admin/env/proposal/new"
  end

  test "explains the problem when this server can't decrypt its credentials" do
    broken = EnvBro::Environment.new(name: "test", content_path: environment.content_path, key_path: "/nonexistent.key", env_key: "ENV_BRO_UNSET_KEY")
    sign_in_as "developer"
    with_current_environment(broken) { get "/admin/env/proposal/new" }
    assert_response :service_unavailable
    assert_select ".badge-danger", text: "no key on server"
  end

  test "developer sees key names but never values" do
    sign_in_as "developer"
    get "/admin/env/proposal/new"
    assert_response :success
    assert_select ".yaml-group", text: "aws:"
    assert_select "[data-leaf='aws.secret_access_key'] .yaml-key.depth-1", text: "secret_access_key:"
    assert_select "[data-leaf='secret_key_base'] .yaml-key.depth-0"
    environment.current_credentials.flatten.each_value do |value|
      refute_includes response.body, value.to_s
    end
    assert_equal "no-store", response.headers["Cache-Control"]
  end

  test "developer downloads a re-encrypted file and the proposal is audited without values" do
    sign_in_as "developer"
    propose(
      new_keys: [ { key: "github.token", secret_value: "ghp_new" }, { key: "", secret_value: "" } ],
      edits: [
        { key: "aws.access_key_id", secret_value: "" },
        { key: "stripe.secret_key", secret_value: "sk_live_rotated" },
        { key: "sendgrid_api_key", secret_value: "", remove: "1" }
      ]
    )

    assert_response :success
    assert_match "attachment", response.headers["Content-Disposition"]
    assert_match "test.yml.enc", response.headers["Content-Disposition"]
    updated = environment.decrypt(response.body)
    assert_equal "sk_live_rotated", updated.flatten["stripe.secret_key"]
    assert_equal "ghp_new", updated.flatten["github.token"]
    assert_equal environment.current_credentials.flatten["aws.access_key_id"], updated.flatten["aws.access_key_id"]
    refute updated.key?("sendgrid_api_key")

    entry = audit_entries.first
    assert_equal "proposal_created", entry.event
    assert_equal EnvBro::Environment.digest(response.body), entry.file_digest
    assert_equal updated.metadata["proposal_id"], entry.proposal_token
    assert_equal "developer@example.com", entry.user_label
    assert_equal [
      { "action" => "set", "key" => "github.token" },
      { "action" => "set", "key" => "stripe.secret_key" },
      { "action" => "delete", "key" => "sendgrid_api_key" }
    ], entry.details["changes"]
    refute_includes EnvBro::AuditEvent.pluck(:details).to_json, "sk_live_rotated"
  end

  test "invalid changes re-render the form with an error" do
    sign_in_as "developer"
    propose(new_keys: [ { key: "bad key", secret_value: "x" } ], edits: [ { key: "stripe.secret_key", secret_value: "kept" } ])
    assert_response :unprocessable_entity
    assert_includes response.body, "Invalid key"
    assert_select "input[name='new_keys[0][key]'][value='bad key']"
    assert_select "[data-leaf='stripe.secret_key'].is-changed textarea", text: "kept"
  end

  test "submitting without any change explains what to do" do
    sign_in_as "developer"
    propose(edits: [ { key: "stripe.secret_key", secret_value: "" } ])
    assert_response :unprocessable_entity
    assert_includes response.body, "Add at least one change"
  end
end
