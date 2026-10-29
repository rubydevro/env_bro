require "test_helper"

class EnvBro::DeploymentsTest < ActiveSupport::TestCase
  def propose(key, created_at: Time.current)
    result = EnvBro::Editor.new(environment).apply([ { key: key, value: "v" } ], author: "dev@example.com")
    event = EnvBro::AuditEvent.create!(event: "proposal_created", environment: "test", user_label: "dev@example.com",
      proposal_token: result.proposal_token, file_digest: result.file_digest,
      details: { "changes" => [ { "action" => "set", "key" => key } ] }, created_at: created_at)
    [ result, event ]
  end

  test "records when a proposal's file is running, once" do
    result, proposal = propose("x")

    deployment = with_deployed_file(result.cipher_text) { EnvBro::Deployments.track }
    assert_equal "proposal_deployed", deployment.event
    assert_equal proposal, deployment.proposal
    refute deployment.modified_after_review?
    assert_equal [ "set x" ], deployment.keys
    assert_equal :live, proposal.reload.deployment_status

    assert_nil with_deployed_file(result.cipher_text) { EnvBro::Deployments.track }
    assert_equal 1, EnvBro::AuditEvent.deployments.count
  end

  test "recognizes a proposal re-encrypted after review by its embedded id" do
    result, proposal = propose("x")
    re_encrypted = environment.encrypt(environment.decrypt(result.cipher_text))
    refute_equal result.file_digest, EnvBro::Environment.digest(re_encrypted)

    deployment = with_deployed_file(re_encrypted) { EnvBro::Deployments.track }
    assert_equal proposal, deployment.proposal
    assert deployment.modified_after_review?
  end

  test "does nothing for a file that did not come from EnvBro" do
    propose("x")
    assert_nil with_deployed_file(environment.current_cipher_text) { EnvBro::Deployments.track }
  end

  test "does nothing when disabled" do
    result, _ = propose("x")
    EnvBro.config.track_deployments = false
    assert_nil with_deployed_file(result.cipher_text) { EnvBro::Deployments.track }
  ensure
    EnvBro.config.track_deployments = true
  end

  test "never raises" do
    broken = EnvBro::Environment.new(name: "test", content_path: "/nonexistent", key_path: "/nonexistent", env_key: "X")
    broken.define_singleton_method(:ready?) { raise "boom" }
    assert_nil with_current_environment(broken) { EnvBro::Deployments.track }
  end

  test "statuses: live, deployed then replaced, superseded, pending" do
    first_result, first = propose("a", created_at: 3.hours.ago)
    _, skipped = propose("b", created_at: 2.hours.ago)
    second_result, second = propose("c", created_at: 1.hour.ago)

    with_deployed_file(first_result.cipher_text) { EnvBro::Deployments.track }
    assert_equal :live, first.reload.deployment_status
    assert_equal :pending, skipped.deployment_status

    with_deployed_file(second_result.cipher_text) { EnvBro::Deployments.track }
    _, newest = propose("d")

    assert_equal :deployed, first.reload.deployment_status
    assert_equal :superseded, skipped.reload.deployment_status
    assert_equal :live, second.reload.deployment_status
    assert_equal :pending, newest.deployment_status
  end
end
