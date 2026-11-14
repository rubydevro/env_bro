require "test_helper"
require "generators/env_bro/install/install_generator"

class EnvBro::Generators::InstallGeneratorTest < Rails::Generators::TestCase
  tests EnvBro::Generators::InstallGenerator
  destination File.expand_path("../../tmp/generator_test", __dir__)

  setup do
    prepare_destination
    FileUtils.mkdir_p File.join(destination_root, "config")
    File.write(File.join(destination_root, "config/routes.rb"), "Rails.application.routes.draw do\nend\n")
  end

  test "creates the initializer with everything denied" do
    run_install
    assert_file "config/initializers/env_bro.rb" do |content|
      %w[create update destroy review reveal].each do |permission|
        assert_match "config.can_#{permission} = ->(user) { false }", content
      end
    end
  end

  test "mounts BroHub, not EnvBro, at the default path when not interactive" do
    with_tty(false) { run_install }
    assert_file "config/routes.rb", %r{mount BroHub::Engine => "/bro_hub"}
    assert_file "config/routes.rb" do |content|
      assert_no_match(/EnvBro::Engine/, content)
    end
    assert_file "config/initializers/bro_hub.rb"
  end

  test "mounts at --mount-path, normalizing slashes" do
    run_install "--mount-path=ops/credentials/"
    assert_file "config/routes.rb", %r{mount BroHub::Engine => "/ops/credentials"}
  end

  test "does not mount BroHub twice" do
    run_install
    run_install "--mount-path=/other"
    assert_file "config/routes.rb" do |content|
      assert_equal 1, content.scan("BroHub::Engine").size
    end
  end

  test "leaves an existing direct EnvBro mount alone and says to remove it" do
    File.write(File.join(destination_root, "config/routes.rb"),
      "Rails.application.routes.draw do\n  mount EnvBro::Engine => \"/admin/env\"\nend\n")
    output = run_install
    assert_file "config/routes.rb", %r{mount EnvBro::Engine => "/admin/env"}
    assert_match "still mounted directly", output
  end

  test "comments out the old direct mount with --remove-direct-mounts" do
    File.write(File.join(destination_root, "config/routes.rb"),
      "Rails.application.routes.draw do\n  mount EnvBro::Engine => \"/admin/env\"\nend\n")
    run_install "--remove-direct-mounts"
    assert_file "config/routes.rb" do |content|
      assert_match %r{# BroHub mounts this now: mount EnvBro::Engine}, content
      assert_no_match(/^\s*mount EnvBro::Engine/, content)
    end
  end

  private
    # Migrations are copied by the engine's rake task, which needs a real host app.
    def run_install(*args)
      install = generator([], args, destination_root: destination_root)
      def install.copy_migrations; end
      with_tty(false) { capture(:stdout) { install.invoke_all } }
    end

    def with_tty(value)
      original = $stdin
      $stdin = StringIO.new
      $stdin.define_singleton_method(:tty?) { value }
      yield
    ensure
      $stdin = original
    end
end
