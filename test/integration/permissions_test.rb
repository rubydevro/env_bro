require "test_helper"

class PermissionsTest < ActionDispatch::IntegrationTest
  test "every propose permission opens the propose page, but only offers what it allows" do
    { "creator" => [ true, false, false ], "updater" => [ false, true, false ], "developer" => [ true, true, true ] }.each do |role, (create, update, destroy)|
      sign_in_as role
      get "/admin/env/proposal/new"
      assert_response :success, role
      assert_select "[data-new-keys]", create ? 1 : 0
      assert_select "[data-leaf='stripe.secret_key'] textarea", update ? 1 : 0
      assert_select "[data-leaf='stripe.secret_key'] [data-remove-toggle]", destroy ? 1 : 0
    end
  end

  test "creators can't see more than key names" do
    sign_in_as "creator"
    get "/admin/env/proposal/new"
    assert_select "[data-leaf='stripe.secret_key']"
    environment.current_credentials.flatten.each_value { |value| refute_includes response.body, value.to_s }
  end

  test "creator adds a key but can't change or remove existing ones" do
    sign_in_as "creator"
    propose(new_keys: [ { key: "github.token", secret_value: "ghp_new" } ])
    assert_response :success
    assert_equal "ghp_new", environment.decrypt(response.body).flatten["github.token"]

    propose(new_keys: [ { key: "stripe.secret_key", secret_value: "sneaky" } ])
    assert_response :forbidden

    propose(edits: [ { key: "stripe.secret_key", secret_value: "sneaky" } ])
    assert_response :forbidden

    propose(edits: [ { key: "sendgrid_api_key", remove: "1" } ])
    assert_response :forbidden
  end

  test "updater changes values but can't add or remove keys" do
    sign_in_as "updater"
    propose(edits: [ { key: "stripe.secret_key", secret_value: "rotated" } ])
    assert_response :success

    propose(new_keys: [ { key: "github.token", secret_value: "x" } ])
    assert_response :forbidden

    propose(edits: [ { key: "sendgrid_api_key", remove: "1" } ])
    assert_response :forbidden
  end

  test "one forbidden change rejects the whole proposal" do
    sign_in_as "updater"
    assert_no_difference -> { EnvBro::AuditEvent.count } do
      propose(edits: [ { key: "stripe.secret_key", secret_value: "rotated" }, { key: "sendgrid_api_key", remove: "1" } ])
    end
    assert_response :forbidden
  end

  test "reviewers and admins can propose without a separate grant" do
    %w[reviewer admin].each do |role|
      sign_in_as role
      get "/admin/env/proposal/new"
      assert_select "[data-new-keys]"
      assert_select "[data-leaf='stripe.secret_key'] [data-remove-toggle]"
      propose(new_keys: [ { key: "github.token", secret_value: "x" } ], edits: [ { key: "sendgrid_api_key", remove: "1" } ])
      assert_response :success, role
    end
  end

  test "reviewers review, but only admins reveal" do
    sign_in_as "reviewer"
    get "/admin/env/review/new"
    assert_response :success
    post "/admin/env/review/reveal", params: { proposed_enc: "x", reveal_key: "*" }
    assert_response :forbidden

    sign_in_as "admin"
    get "/admin/env/review/new"
    assert_response :success
  end

  test "propose-only users don't get the review pages" do
    sign_in_as "creator"
    get "/admin/env/review/new"
    assert_response :forbidden
    get "/admin/env/audit"
    assert_response :forbidden
  end

  test "reviewers land on the propose page, viewers get nothing" do
    sign_in_as "reviewer"
    get "/admin/env"
    assert_redirected_to "/admin/env/proposal/new"

    sign_in_as "viewer"
    get "/admin/env/proposal/new"
    assert_response :forbidden
  end
end
