module EnvBro
  module ApplicationHelper
    def env_bro_masked(value)
      return content_tag(:span, "(none)", class: "muted") if value.nil?
      length = env_bro_format_value(value).length
      content_tag(:span, "•" * [ length, 12 ].min, class: "mask", title: "#{length} characters") +
        content_tag(:span, " #{length} chars", class: "muted small")
    end

    def env_bro_value(value)
      return content_tag(:span, "(none)", class: "muted") if value.nil?
      content_tag(:code, env_bro_format_value(value), class: "value")
    end

    def env_bro_format_value(value)
      value.is_a?(String) ? value : value.to_json
    end

    def env_bro_status_badge(status)
      content_tag(:span, status.to_s, class: "badge badge-#{status}")
    end

    ENVIRONMENT_BADGES = {
      ready: [ "ready", "ok" ],
      missing_file: [ "file missing", "danger" ],
      missing_key: [ "no key on server", "danger" ],
      wrong_key: [ "key doesn't match", "danger" ]
    }.freeze

    def env_bro_environment_badge(status)
      label, style = ENVIRONMENT_BADGES.fetch(status)
      content_tag(:span, label, class: "badge badge-#{style}")
    end

    def env_bro_time(time)
      time.utc.strftime("%Y-%m-%d %H:%M UTC")
    end

    # Status of a proposal_created event: live / deployed / superseded / pending.
    def env_bro_deployment_badge(proposal, live)
      case proposal.deployment_status(live)
      when :live then content_tag(:span, "live since #{env_bro_time(proposal.deployment.created_at)}", class: "badge badge-ok")
      when :deployed then content_tag(:span, "deployed #{env_bro_time(proposal.deployment.created_at)}, replaced since", class: "badge badge-neutral")
      when :superseded then content_tag(:span, "superseded", class: "badge badge-neutral", title: "Never deployed. A newer proposal is live.")
      else content_tag(:span, "not deployed yet", class: "badge badge-changed")
      end
    end

    def env_bro_display_path(path)
      path.relative_path_from(Rails.root).to_s
    rescue ArgumentError
      path.to_s
    end

    def env_bro_short_digest(digest)
      digest.to_s.first(12)
    end
  end
end
