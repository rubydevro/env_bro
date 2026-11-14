module EnvBro
  module ApplicationHelper
    # EnvBro's additions to BroHub's styles, once per page (and nonce-friendly).
    def env_bro_styles
      content_for(:head, render("env_bro/shared/page_styles")) unless content_for?(:head)
      nil
    end

    def env_bro_masked(value)
      return content_tag(:span, "(none)", class: "bh-cell-muted") if value.nil?
      length = env_bro_format_value(value).length
      content_tag(:span, "•" * [ length, 12 ].min, class: "mask", title: "#{length} characters") +
        content_tag(:span, " #{length} chars", class: "bh-cell-muted")
    end

    def env_bro_value(value)
      return content_tag(:span, "(none)", class: "bh-cell-muted") if value.nil?
      content_tag(:code, env_bro_format_value(value), class: "value")
    end

    def env_bro_format_value(value)
      value.is_a?(String) ? value : value.to_json
    end

    STATUS_TAGS = { "added" => "is-green", "changed" => "is-amber", "removed" => "is-red", "unchanged" => "" }.freeze

    def env_bro_status_badge(status)
      content_tag(:span, status.to_s, class: [ "bh-tag", STATUS_TAGS[status.to_s], "tag-#{status}" ].compact_blank)
    end

    ENVIRONMENT_BADGES = {
      ready: [ "ready", "is-green" ],
      missing_file: [ "file missing", "is-red" ],
      missing_key: [ "no key on server", "is-red" ],
      wrong_key: [ "key doesn't match", "is-red" ]
    }.freeze

    def env_bro_environment_badge(status)
      label, style = ENVIRONMENT_BADGES.fetch(status)
      content_tag(:span, label, class: "bh-tag #{style}")
    end

    def env_bro_time(time)
      time.utc.strftime("%Y-%m-%d %H:%M UTC")
    end

    # Status of a proposal_created event: live / deployed / superseded / pending.
    def env_bro_deployment_badge(proposal, live)
      case proposal.deployment_status(live)
      when :live then content_tag(:span, "live since #{env_bro_time(proposal.deployment.created_at)}", class: "bh-tag is-green")
      when :deployed then content_tag(:span, "deployed #{env_bro_time(proposal.deployment.created_at)}, replaced since", class: "bh-tag")
      when :superseded then content_tag(:span, "superseded", class: "bh-tag", title: "Never deployed. A newer proposal is live.")
      else content_tag(:span, "not deployed yet", class: "bh-tag is-amber")
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
