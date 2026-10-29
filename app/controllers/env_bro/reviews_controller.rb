module EnvBro
  class ReviewsController < ApplicationController
    REVEAL_ALL = "*"

    before_action { env_bro_authorize!(:review) }
    before_action(only: :reveal) { env_bro_authorize!(:reveal) }
    before_action :env_bro_require_ready

    def new
    end

    def create
      @proposed_enc = read_upload(:proposed_file) or raise EnvBro::Error, "Choose the proposed #{@environment.filename} to review."
      @base_enc = read_upload(:base_file)
      build_diff

      Audit.record(:review_viewed, user: env_bro_user,
        changed_keys: @differ.changes.map { |e| "#{e.status} #{e.key}" },
        base: @base_enc ? "uploaded" : "deployed")

      @revealed = []
      render :show
    rescue *EnvBro::USER_FACING_ERRORS => e
      @error = e.message
      render :new, status: :unprocessable_entity
    end

    # The encrypted files travel back with the form, so the server never stores them.
    def reveal
      @proposed_enc = params[:proposed_enc].to_s
      @base_enc = params[:base_enc].presence
      build_diff

      requested = params[:reveal_key].to_s
      @revealed = requested == REVEAL_ALL ? @differ.changes.map(&:key) : [ requested ] & @differ.entries.map(&:key)

      Audit.record(:values_revealed, user: env_bro_user, keys: @revealed) if @revealed.any?

      render :show
    rescue *EnvBro::USER_FACING_ERRORS => e
      @error = e.message
      render :new, status: :unprocessable_entity
    end

    private
      def build_diff
        base_cipher_text = @base_enc || @environment.current_cipher_text
        @base_digest = Environment.digest(base_cipher_text)
        @differ = Differ.new(@environment.decrypt(base_cipher_text), @environment.decrypt(@proposed_enc))
        @base_status = @differ.base_status(@base_digest)

        token = @differ.proposed_metadata&.fetch("proposal_id", nil)
        @proposal_event = AuditEvent.proposals.includes(:deployment).find_by(proposal_token: token) if token.present?
      end

      def read_upload(name)
        file = params[name]
        return nil if file.blank?
        raise EnvBro::Error, "#{file.original_filename} is too large." if file.size > EnvBro.config.max_upload_bytes
        file.read.strip
      end
  end
end
