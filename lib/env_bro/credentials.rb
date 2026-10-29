require "yaml"

module EnvBro
  # Decrypted credentials as a nested hash, addressed with dotted key paths
  # ("aws.access_key_id"). The EnvBro metadata key is kept apart from the rest.
  class Credentials
    SEGMENT = /\A[A-Za-z0-9_\-]+\z/

    attr_reader :data

    def self.parse(yaml)
      data = YAML.respond_to?(:unsafe_load) ? YAML.unsafe_load(yaml) : YAML.load(yaml)
      data = {} if data.blank?
      raise Error, "Credentials must be a YAML mapping at the top level" unless data.is_a?(Hash)
      new(data)
    end

    def self.split(path)
      segments = path.to_s.strip.split(".")
      if segments.empty? || segments.any? { |s| !s.match?(SEGMENT) }
        raise InvalidChange, "Invalid key #{path.inspect}. Use letters, digits, _ and -, nested with dots (aws.secret_key)."
      end
      segments
    end

    def initialize(data)
      @data = data
    end

    def metadata
      key = EnvBro.config.metadata_key
      key ? (data[key] || data[key.to_sym]) : nil
    end

    def metadata=(value)
      key = EnvBro.config.metadata_key or return
      data.delete(key.to_sym)
      data[key] = value
    end

    # One line of the YAML-like outline shown to proposers: a group ("aws:") or a key.
    Line = Struct.new(:path, :name, :depth, :group, keyword_init: true)

    # { "aws.access_key_id" => "AKIA...", "secret_key_base" => "..." }, without metadata.
    def flatten
      flatten_hash(without_metadata)
    end

    # Groups and keys in file order, with their nesting depth. No values.
    def outline(hash = without_metadata, prefix = nil, depth = 0, lines = [])
      hash.each do |key, value|
        path = [ prefix, key.to_s ].compact.join(".")
        group = value.is_a?(Hash) && value.any?
        lines << Line.new(path: path, name: key.to_s, depth: depth, group: group)
        outline(value, path, depth + 1, lines) if group
      end
      lines
    end

    def key_paths
      flatten.keys
    end

    def key?(path)
      flatten.key?(path)
    end

    def set(path, value)
      *parents, leaf = self.class.split(path)
      node = data
      parents.each do |segment|
        key = find_key(node, segment) || segment
        if node[key].nil?
          node = node[key] = {}
        elsif node[key].is_a?(Hash)
          node = node[key]
        else
          raise InvalidChange, "Cannot set #{path}: #{segment} already holds a value, not a group of keys."
        end
      end
      existing_leaf = find_key(node, leaf)
      if existing_leaf && node[existing_leaf].is_a?(Hash)
        raise InvalidChange, "Cannot set #{path}: it is a group of keys, set one of its children instead."
      end
      node[existing_leaf || leaf] = value
    end

    def delete(path)
      *parents, leaf = self.class.split(path)
      chain = [ data ]
      parents.each do |segment|
        child = chain.last[find_key(chain.last, segment)]
        raise InvalidChange, "Cannot remove #{path}: key does not exist." unless child.is_a?(Hash)
        chain << child
      end
      existing_leaf = find_key(chain.last, leaf)
      raise InvalidChange, "Cannot remove #{path}: key does not exist." if existing_leaf.nil?
      chain.last.delete(existing_leaf)

      # Drop groups left empty by the removal.
      parents.reverse.each_with_index do |segment, i|
        parent = chain[-(i + 2)]
        key = find_key(parent, segment)
        parent.delete(key) if parent[key].is_a?(Hash) && parent[key].empty?
      end
    end

    def to_yaml
      YAML.dump(data)
    end

    private
      def without_metadata
        data.except(EnvBro.config.metadata_key, EnvBro.config.metadata_key&.to_sym)
      end

      # Credentials keys are usually strings but may be symbols (":foo:" in YAML).
      def find_key(hash, segment)
        if hash.key?(segment) then segment
        elsif hash.key?(segment.to_sym) then segment.to_sym
        end
      end

      def flatten_hash(hash, prefix = nil)
        hash.each_with_object({}) do |(key, value), out|
          path = [ prefix, key.to_s ].compact.join(".")
          if value.is_a?(Hash) && value.any?
            out.merge!(flatten_hash(value, path))
          else
            out[path] = value
          end
        end
      end
  end
end
