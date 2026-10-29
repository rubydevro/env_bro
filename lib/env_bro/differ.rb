module EnvBro
  # Compares two decrypted credentials (base vs proposed) key by key.
  class Differ
    Entry = Struct.new(:key, :status, :old_value, :new_value, keyword_init: true) do
      def changed?
        status != :unchanged
      end
    end

    STATUS_ORDER = { added: 0, changed: 1, removed: 2, unchanged: 3 }.freeze

    attr_reader :base, :proposed

    def initialize(base, proposed)
      @base = base
      @proposed = proposed
    end

    def entries
      @entries ||= begin
        old_flat = base.flatten
        new_flat = proposed.flatten
        keys = (old_flat.keys | new_flat.keys)

        keys.map do |key|
          status =
            if !old_flat.key?(key) then :added
            elsif !new_flat.key?(key) then :removed
            elsif old_flat[key] == new_flat[key] then :unchanged
            else :changed
            end
          Entry.new(key: key, status: status, old_value: old_flat[key], new_value: new_flat[key])
        end.sort_by { |e| [ STATUS_ORDER[e.status], e.key ] }
      end
    end

    def changes
      entries.select(&:changed?)
    end

    def counts
      entries.group_by(&:status).transform_values(&:size)
    end

    def proposed_metadata
      proposed.metadata.is_a?(Hash) ? proposed.metadata : nil
    end

    # :current  - proposal was built on the base we compare against
    # :stale    - proposal was built on a different version of the file
    # :unknown  - proposal carries no EnvBro metadata (made by hand, or an old file)
    def base_status(base_digest)
      recorded = proposed_metadata&.fetch("base_digest", nil)
      return :unknown if recorded.blank?
      recorded == base_digest ? :current : :stale
    end
  end
end
