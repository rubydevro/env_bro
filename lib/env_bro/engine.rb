module EnvBro
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
