module EnvBro
  # Who proposed, reviewed or revealed what, and when proposals went live.
  # Holds key names only, never values.
  class AuditEvent < ApplicationRecord
    EVENTS = %w[proposal_created proposal_deployed review_viewed values_revealed].freeze

    belongs_to :proposal, class_name: "EnvBro::AuditEvent", optional: true
    has_one :deployment, -> { where(event: "proposal_deployed") }, class_name: "EnvBro::AuditEvent", foreign_key: :proposal_id

    validates :event, inclusion: { in: EVENTS }
    validates :environment, presence: true

    scope :recent, -> { order(created_at: :desc, id: :desc) }
    scope :proposals, -> { where(event: "proposal_created") }
    scope :deployments, -> { where(event: "proposal_deployed") }

    # Audit entries are append-only.
    def readonly?
      persisted?
    end

    # Key names touched by the event, for display.
    def keys
      if event == "proposal_deployed"
        proposal&.keys || []
      elsif details["changes"]
        details["changes"].map { |c| "#{c['action']} #{c['key']}" }
      else
        Array(details["changed_keys"] || details["keys"])
      end
    end

    # The proposal whose file is running right now, if it came from EnvBro.
    def self.live_proposal
      deployments.recent.first&.proposal
    end

    # For a proposal_created event:
    #   :live       - its file is what's deployed now
    #   :deployed   - it was deployed, a later proposal replaced it
    #   :superseded - never deployed, and a newer proposal is live
    #   :pending    - not deployed (yet)
    def deployment_status(live = self.class.live_proposal)
      if deployment
        live&.id == id ? :live : :deployed
      elsif live && live.created_at > created_at
        :superseded
      else
        :pending
      end
    end

    # The deployed file differs from the one EnvBro handed out (re-saved with
    # `rails credentials:edit` after review, for instance).
    def modified_after_review?
      event == "proposal_deployed" && details["modified_after_review"] == true
    end
  end
end
