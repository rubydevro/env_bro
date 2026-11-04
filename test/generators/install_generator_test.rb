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
      assert_match "config.can_propose = ->(user) { false }", content
    end
  end

  test "mounts at the default path when not interactive" do
    with_tty(false) { run_install }
    assert_file "config/routes.rb", %r{mount EnvBro::Engine => "/admin/env"}
  end

  test "mounts at --mount-path, normalizing slashes" do
    run_install "--mount-path=ops/credentials/"
    assert_file "config/routes.rb", %r{mount EnvBro::Engine => "/ops/credentials"}
  end

  test "asks for the path when interactive" do
    install = generator([], {}, destination_root: destination_root)
    def install.copy_migrations; end
    def install.ask(question, **opts)
      (@asked ||= []) << [ question, opts ]
      "secrets"
    end
    with_tty(true) { capture(:stdout) { install.invoke_all } }

    assert_equal [ [ "Where should EnvBro be mounted?", { default: "/admin/env" } ] ], install.instance_variable_get(:@asked)
    assert_file "config/routes.rb", %r{mount EnvBro::Engine => "/secrets"}
  end

  test "does not mount twice" do
    run_install
    run_install "--mount-path=/other"
    assert_file "config/routes.rb" do |content|
      assert_equal 1, content.scan("EnvBro::Engine").size
    end
  end

  private
    # Migrations are copied by the engine's rake task, which needs a real host app.
    def run_install(*args)
      install = generator([], args, destination_root: destination_root)
      def install.copy_migrations; end
      capture(:stdout) { install.invoke_all }
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
