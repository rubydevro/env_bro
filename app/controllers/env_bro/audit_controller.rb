module EnvBro
  class AuditController < ApplicationController
    before_action { env_bro_authorize!(:review) }

    def index
      @events = AuditEvent.recent.includes(:deployment, proposal: :deployment).limit(200)
      @live_proposal = AuditEvent.live_proposal
    end
  end
end
