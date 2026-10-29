module EnvBro
  # Records who did what in EnvBro::AuditEvent. Never records secret values, only key names.
  module Audit
    module_function

    # columns: extra AuditEvent attributes (proposal_token, file_digest, proposal).
    def record(event, user:, columns: {}, **details)
      EnvBro::AuditEvent.create!(
        event: event.to_s,
        user_label: user.is_a?(String) ? user : EnvBro.config.user_label.call(user).to_s,
        environment: Rails.env.to_s,
        details: details.deep_stringify_keys,
        **columns
      )
    end
  end
end
