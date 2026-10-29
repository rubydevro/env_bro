require "active_support/encrypted_file"

module EnvBro
  # Reuses Rails' own EncryptedFile (cipher, serializer, key lookup) but lets us
  # encrypt/decrypt arbitrary strings in memory instead of writing to disk.
  class EncryptedBlob < ActiveSupport::EncryptedFile
    def encrypt_string(plain)
      encrypt(plain)
    end

    def decrypt_string(cipher_text)
      decrypt(cipher_text.to_s.strip)
    rescue ActiveSupport::MessageEncryptor::InvalidMessage, ArgumentError
      raise DecryptionError, "This file could not be decrypted with the #{content_path.basename} key. " \
        "It is either for another environment or corrupted."
    end
  end
end
