module EnvBro
  # Rails reads credentials once, at boot. On boot we look at the credentials file
  # this app is running with and, if it came from an EnvBro proposal, record when
  # that proposal went live.
  module Deployments
    module_function

    # Returns the proposal_deployed event created, or nil. Never raises: this
    # runs during boot and must not take the app down (no DB during
    # assets:precompile, migrations not run yet, ...).
    def track
      return unless EnvBro.config.track_deployments
      return unless AuditEvent.table_exists?

      environment = Environment.current
      return unless environment.ready?

      digest = Environment.digest(environment.current_cipher_text)
      proposal = AuditEvent.proposals.find_by(file_digest: digest)
      modified = false

      # The file was re-encrypted after review but still carries the proposal's id.
      if proposal.nil?
        token = environment.current_credentials.metadata.to_h["proposal_id"]
        proposal = AuditEvent.proposals.find_by(proposal_token: token) if token.present?
        modified = proposal.present?
      end

      return if proposal.nil? || AuditEvent.deployments.exists?(proposal_id: proposal.id)

      Audit.record(:proposal_deployed, user: "deploy",
        columns: { proposal: proposal, file_digest: digest },
        modified_after_review: modified)
    rescue ActiveRecord::RecordNotUnique
      nil # another process recorded it first
    rescue StandardError => e
      Rails.logger&.warn("[EnvBro] could not check deployed credentials: #{e.class}: #{e.message}")
      nil
    end
  end
end
