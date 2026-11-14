require "test_helper"

# EnvBro inside BroHub (the way it is meant to be mounted) and mounted on its own (EnvBro 0.1.x hosts).
class ShellTest < ActionDispatch::IntegrationTest
  test "EnvBro renders inside the BroHub shell" do
    sign_in_as "developer"
    get "/bro_hub/env_bro/proposal/new"
    assert_response :success
    assert_select ".bh-top", /powered by\s+DeadBro/
    assert_select ".bh-top .bh-user", "developer@example.com"
    assert_select ".bh-group-label", "EnvBro · config"
    assert_select ".bh-crumb", /EnvBro \/ test \/ Propose a change/
    assert_select "a.bh-nav.is-active[href='/bro_hub/env_bro/proposal/new']", /Propose a change/
    assert_select "a.bh-nav[href='/bro_hub/env_bro']", /Environments/
  end

  test "the section is hidden from people with no EnvBro permission, and the hub root finds it for the others" do
    sign_in_as "viewer"
    get "/bro_hub"
    assert_response :forbidden
    assert_select ".bh-group-label", text: "EnvBro · config", count: 0

    sign_in_as "creator"
    get "/bro_hub"
    assert_redirected_to "/bro_hub/env_bro"
  end

  test "configuring the user once in BroHub is enough" do
    original = BroHub.config.current_user
    BroHub.config.current_user = ->(_controller) { User.for_role("reviewer") }
    get "/bro_hub/env_bro/review/new"   # nobody signed in through the dummy app
    assert_response :success
    assert_select ".bh-user", "reviewer@example.com"
  ensure
    BroHub.config.current_user = original
  end

  test "an engine mounted directly keeps working, with just its own section" do
    sign_in_as "developer"
    get "/admin/env"
    assert_response :success
    assert_select ".bh-group-label", count: 1
    assert_select "a.bh-nav[href='/admin/env/proposal/new']", /Propose a change/

    get "/admin/env/proposal/new"
    assert_response :success
    assert_select "a.bh-nav.is-active[href='/admin/env/proposal/new']"
    assert_select "[data-new-keys]"
  end

  test "pages still refuse to be cached" do
    sign_in_as "admin"
    get "/bro_hub/env_bro/proposal/new"
    assert_equal "no-store", response.headers["Cache-Control"]
  end
end
