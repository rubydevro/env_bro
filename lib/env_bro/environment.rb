require "digest"
require "pathname"

module EnvBro
  # The credentials file of the environment the app runs in, located exactly the
  # way Rails finds it (config.credentials.content_path, RAILS_MASTER_KEY, ...).
  class Environment
    attr_reader :name, :content_path, :key_path, :env_key

    def self.current
      credentials = Rails.application.credentials
      new(name: Rails.env, content_path: credentials.content_path, key_path: credentials.key_path, env_key: credentials.env_key)
    end

    def initialize(name:, content_path:, key_path:, env_key:)
      @name = name.to_s
      @content_path = Pathname.new(content_path.to_s)
      @key_path = Pathname.new(key_path.to_s)
      @env_key = env_key
    end

    def filename
      content_path.basename.to_s
    end

    def exists?
      content_path.exist?
    end

    def key?
      blob(raise_if_missing_key: false).key?.present?
    end

    # :ready, :missing_file, :missing_key or :wrong_key.
    def status
      return :missing_file unless exists?
      return :missing_key unless key?
      current_credentials
      :ready
    rescue DecryptionError, ActiveSupport::EncryptedFile::InvalidKeyLengthError
      :wrong_key
    end

    def ready?
      status == :ready
    end

    # Encrypted bytes as deployed on this server.
    def current_cipher_text
      content_path.binread.strip
    end

    def current_credentials
      decrypt(current_cipher_text)
    end

    def decrypt(cipher_text)
      Credentials.parse(blob.decrypt_string(cipher_text))
    end

    def encrypt(credentials)
      blob.encrypt_string(credentials.to_yaml)
    end

    def self.digest(cipher_text)
      Digest::SHA256.hexdigest(cipher_text.to_s.strip)
    end

    private
      def blob(raise_if_missing_key: true)
        EncryptedBlob.new(content_path: content_path, key_path: key_path, env_key: env_key, raise_if_missing_key: raise_if_missing_key)
      end
  end
end
