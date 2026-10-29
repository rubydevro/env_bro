# Stand-in for the host app's user model. Roles: viewer, developer, admin.
class User
  ROLES = %w[viewer developer admin].freeze

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

  def developer?
    role.in?(%w[developer admin])
  end

  def admin?
    role == "admin"
  end
end
