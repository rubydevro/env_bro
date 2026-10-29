require "time"
require "securerandom"

module EnvBro
  # Applies a list of changes to an environment's current credentials, in memory,
  # and returns the re-encrypted file. Nothing is written to disk.
  class Editor
    ACTIONS = %w[set delete].freeze

    Change = Struct.new(:action, :key, :value, keyword_init: true) do
      def description
        action == "delete" ? "remove #{key}" : "set #{key}"
      end
    end

    Result = Struct.new(:cipher_text, :filename, :changes, :base_digest, :proposal_token, keyword_init: true) do
      # SHA-256 of the file handed out; seeing it deployed means the proposal is live.
      def file_digest
        Environment.digest(cipher_text)
      end
    end

    attr_reader :environment

    def initialize(environment)
      @environment = environment
    end

    # changes: array of hashes/Changes with action ("set"/"delete"), key and value.
    def apply(changes, author:)
      changes = normalize(changes)
      raise InvalidChange, "Add at least one change." if changes.empty?

      base_cipher_text = environment.current_cipher_text
      credentials = environment.decrypt(base_cipher_text)

      changes.each do |change|
        if change.action == "delete"
          credentials.delete(change.key)
        else
          credentials.set(change.key, change.value)
        end
      end

      base_digest = Environment.digest(base_cipher_text)
      proposal_token = SecureRandom.uuid
      credentials.metadata = {
        "proposal_id" => proposal_token,
        "base_digest" => base_digest,
        "proposed_by" => author.to_s,
        "proposed_at" => Time.now.utc.iso8601,
        "changes" => changes.map(&:description)
      }

      Result.new(
        cipher_text: environment.encrypt(credentials),
        filename: environment.filename,
        changes: changes,
        base_digest: base_digest,
        proposal_token: proposal_token
      )
    end

    private
      def normalize(changes)
        changes = Array(changes).map { |c| c.is_a?(Change) ? c : Change.new(**c.to_h.symbolize_keys.slice(:action, :key, :value)) }
        changes = changes.reject { |c| c.key.blank? && c.value.blank? }

        changes.each do |change|
          change.action = change.action.presence || "set"
          change.key = change.key.to_s.strip
          raise InvalidChange, "Unknown action #{change.action.inspect}." unless ACTIONS.include?(change.action)
          Credentials.split(change.key)
          if metadata_key?(change.key)
            raise InvalidChange, "#{change.key} is reserved for EnvBro metadata."
          end

          if change.action == "set"
            change.value = clean_value(change.value)
            raise InvalidChange, "#{change.key} needs a value." if change.value.empty?
          else
            change.value = nil
          end
        end

        duplicates = changes.map(&:key).tally.select { |_, n| n > 1 }.keys
        raise InvalidChange, "Each key can only be changed once per proposal: #{duplicates.join(', ')}." if duplicates.any?

        changes
      end

      # Browsers send textarea newlines as CRLF. Single-line values are stripped
      # because a stray space or newline in an API key is a classic bug.
      def clean_value(value)
        value = value.to_s.gsub("\r\n", "\n").sub(/\n+\z/, "")
        value.include?("\n") ? value : value.strip
      end

      def metadata_key?(key)
        meta = EnvBro.config.metadata_key
        meta && Credentials.split(key).first == meta
      end
  end
end
