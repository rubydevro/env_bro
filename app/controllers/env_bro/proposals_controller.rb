module EnvBro
  class ProposalsController < ApplicationController
    before_action { env_bro_authorize!(:propose) } # any of create, update, destroy
    before_action :env_bro_require_ready

    helper_method :can_create?, :can_update?, :can_destroy?

    def new
      @new_keys = [ Editor::Change.new(action: "set") ]
      @edits = {}
      load_outline
    end

    def create
      @new_keys = new_key_params
      @edits = edit_params.index_by(&:key)
      changes = @new_keys + @edits.values.reject { |c| c.action == "set" && c.value.blank? }

      authorize_changes!(changes)

      result = Editor.new(@environment).apply(changes, author: EnvBro.config.user_label.call(env_bro_user))

      Audit.record(:proposal_created, user: env_bro_user,
        columns: { proposal_token: result.proposal_token, file_digest: result.file_digest },
        changes: result.changes.map { |c| { "action" => c.action, "key" => c.key } },
        base_digest: result.base_digest)

      send_data result.cipher_text, filename: result.filename, type: "application/octet-stream", disposition: "attachment"
    rescue *EnvBro::USER_FACING_ERRORS => e
      @error = e.message
      @new_keys = [ Editor::Change.new(action: "set") ] if @new_keys.blank?
      @edits ||= {}
      load_outline
      render :new, status: :unprocessable_entity
    end

    private
      def can_create? = env_bro_can?(:create)
      def can_update? = env_bro_can?(:update)
      def can_destroy? = env_bro_can?(:destroy)

      # Each change needs the matching permission: removing a key is destroy, setting a key
      # that already exists is update, setting a new one is create. Checked on the server, so
      # a hand-built request can't do more than the form offers.
      def authorize_changes!(changes)
        existing = @environment.current_credentials
        changes.each do |change|
          key = change.key.to_s.strip
          next if key.empty?
          permission = change.action == "delete" ? :destroy : (existing.key?(key) ? :update : :create)
          env_bro_authorize!(permission)
        end
      end

      # new_keys[0][key], new_keys[0][secret_value], ...
      def new_key_params
        indexed_rows(:new_keys).map do |row|
          Editor::Change.new(action: "set", key: row[:key], value: row[:secret_value])
        end
      end

      # edits[0][key], edits[0][secret_value], edits[0][remove], ... one per existing key.
      def edit_params
        indexed_rows(:edits).map do |row|
          remove = row[:remove] == "1"
          Editor::Change.new(action: remove ? "delete" : "set", key: row[:key], value: remove ? nil : row[:secret_value])
        end
      end

      # Form rows posted with numeric indexes (which may have gaps), in order.
      def indexed_rows(name)
        rows = params[name]
        return [] unless rows.respond_to?(:to_unsafe_h)
        rows.to_unsafe_h.sort_by { |index, _| index.to_i }.map do |_, row|
          ActionController::Parameters.new(row).permit(:key, :secret_value, :remove)
        end
      end

      def load_outline
        @outline = @environment.current_credentials.outline
      rescue *EnvBro::USER_FACING_ERRORS => e
        @outline = []
        @error ||= e.message
      end
  end
end
