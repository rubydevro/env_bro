module EnvBro
  # Records who did what, through BroHub's audit table. Never records secret values, only key names.
  module Audit
    module_function

    # columns: proposal_token and file_digest (stored as BroHub's reference and digest) and proposal (the row a
    # deployment belongs to).
    def record(event, user:, columns: {}, **details)
      BroHub::Audit.record(
        source: EnvBro::AuditEvent::SOURCE, model: EnvBro::AuditEvent, event: event,
        user: user.is_a?(String) ? user : EnvBro.config.user_label.call(user).to_s,
        reference: columns[:proposal_token], digest: columns[:file_digest], parent: columns[:proposal],
        **details
      )
    end
  end
end
