module EnvBro
  # Items in the BroHub sidebar. Paths are relative to the engine.
  BRO_HUB_ITEMS = [
    { label: "Environments", path: "/" },
    { label: "Propose a change", path: "/proposal/new" },
    { label: "Review", path: "/review/new", match: %r{\A/review} },
    { label: "Audit log", path: "/audit" }
  ].freeze

  class Engine < ::Rails::Engine
    isolate_namespace EnvBro

    # Secret values and uploaded files must never end up in the host's logs.
    initializer "env_bro.filter_parameters" do |app|
      app.config.filter_parameters += %i[secret_value proposed_file base_file proposed_enc base_enc]
    end

    # Credentials are read at boot, so this is when a merged proposal takes effect.
    config.after_initialize do
      EnvBro::Deployments.track
    end
  end
end

# Registered when the gem loads, so it is in place before routes are drawn and BroHub can mount the engine.
# Showing a section is navigation only: every EnvBro controller still authorizes each request.
BroHub.register :env_bro, name: "EnvBro", label: "EnvBro · config", accent: :green,
  engine: "EnvBro::Engine", order: 20, items: EnvBro::BRO_HUB_ITEMS,
  visible_to: ->(user) { EnvBro.config.allows?(user, :propose) || EnvBro.config.allows?(user, :review) }
