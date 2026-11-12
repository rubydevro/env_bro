require "test_helper"

class ConfigurationTest < ActiveSupport::TestCase
  setup { @config = EnvBro::Configuration.new }

  def grant(*permissions)
    permissions.each { |p| @config.public_send(:"can_#{p}=", ->(_user) { true }) }
    :user
  end

  test "everything is denied by default, and for signed out users" do
    EnvBro::Configuration::PERMISSIONS.each { |p| refute @config.allows?(:user, p) }
    grant(:reveal)
    refute @config.allows?(nil, :create)
  end

  test "create, update and destroy are independent" do
    user = grant(:update)
    assert @config.allows?(user, :update)
    refute @config.allows?(user, :create)
    refute @config.allows?(user, :destroy)
    refute @config.allows?(user, :review)
  end

  test "propose means any of create, update or destroy" do
    refute @config.allows?(:user, :propose)
    assert @config.allows?(grant(:destroy), :propose)
  end

  test "review includes create, update and destroy but not reveal" do
    user = grant(:review)
    %i[create update destroy review propose].each { |p| assert @config.allows?(user, p), p }
    refute @config.allows?(user, :reveal)
  end

  test "reveal includes everything" do
    user = grant(:reveal)
    EnvBro::Configuration::PERMISSIONS.each { |p| assert @config.allows?(user, p), p }
    assert @config.allows?(user, :propose)
  end

  test "can_propose= grants create, update and destroy" do
    @config.can_propose = ->(_user) { true }
    %i[create update destroy].each { |p| assert @config.allows?(:user, p), p }
    refute @config.allows?(:user, :review)
  end

  test "unknown permissions raise" do
    assert_raises(ArgumentError) { @config.allows?(:user, :delete) }
  end
end
