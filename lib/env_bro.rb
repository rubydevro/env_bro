require "env_bro/version"
require "env_bro/configuration"
require "env_bro/environment"
require "env_bro/encrypted_blob"
require "env_bro/credentials"
require "env_bro/editor"
require "env_bro/differ"
require "env_bro/audit"
require "env_bro/deployments"
require "env_bro/engine"

module EnvBro
  class Error < StandardError; end
  class DecryptionError < Error; end
  class InvalidChange < Error; end
  class Forbidden < StandardError; end

  # Problems we show to the user instead of raising a 500.
  USER_FACING_ERRORS = [
    Error,
    ActiveSupport::EncryptedFile::MissingKeyError,
    ActiveSupport::EncryptedFile::InvalidKeyLengthError,
    Errno::ENOENT,
    Psych::SyntaxError
  ].freeze

  class << self
    def config
      @config ||= Configuration.new
    end

    def configure
      yield config
    end

    def reset_config!
      @config = nil
    end
  end
end
