# Stand-in for the host app's user model. Each role holds one permission; the higher
# ones (reviewer, admin) pick up the lower ones through EnvBro's hierarchy.
class User
  PERMISSIONS = {
    "viewer" => [],
    "creator" => %i[create],
    "updater" => %i[update],
    "developer" => %i[create update destroy],
    "reviewer" => %i[review],
    "admin" => %i[reveal]
  }.freeze
  ROLES = PERMISSIONS.keys.freeze

  attr_reader :role

  def self.for_role(role)
    new(role) if ROLES.include?(role)
  end

  def initialize(role)
    @role = role
  end

  def email
    "#{role}@example.com"
  end

  def can?(permission)
    PERMISSIONS.fetch(role).include?(permission)
  end
end
