# EnvBro

Propose changes to Rails encrypted credentials without holding the keys.

EnvBro manages the credentials of the environment it runs in: on production it edits
`production.yml.enc`, on staging `staging.yml.enc`. Team members with permission open `/admin/env`,
pick keys to add, change or remove, and download the re-encrypted file. They commit it on a branch and open a PR. A reviewer uploads the
file from the PR and sees which keys changed, with values masked unless they choose to reveal them.

The encryption key never leaves the server, and EnvBro never writes to the credentials file.

## How it works

1. **Propose:** the user sees key names only, never values. EnvBro decrypts the deployed file in memory,
   applies the changes, re-encrypts it with the same key and sends it back as a download.
2. **Metadata:** the new file includes an `env_bro` key holding a proposal id, the SHA-256 of the file it was built on,
   the author, the time and the list of declared changes.
3. **Review:** the reviewer uploads the proposed file. EnvBro decrypts it and the deployed file (or an
   uploaded base file, such as the one on `main`), then shows added, changed and removed keys.
   - **Outdated base:** shown when the proposal was built on a different version than the one it is
     compared against. Encrypted files can't be merged, so a stale file would undo other people's changes.
   - **Not built with EnvBro:** shown when the file has no metadata. It may have been edited by hand,
     or it may be an older valid copy that someone is replaying.
4. **Audit:** proposals, reviews and every value reveal are stored in the `env_bro_audit_events`
   table (`EnvBro::AuditEvent`) with key names only. Rows are append-only.
5. **Deployment tracking:** Rails reads credentials at boot, so on boot EnvBro checks whether the
   running file came from a proposal and records a `proposal_deployed` event. The audit log then shows
   each proposal as *live since …*, *deployed, replaced since*, *superseded* or *not deployed yet*.
   - The match uses the SHA-256 of the file EnvBro handed out.
   - If the file was re-encrypted after review (e.g. `rails credentials:edit` to fix a conflict),
     EnvBro recognizes it by the proposal id in its metadata and flags it *modified after review*.
   - The check never stops the app from booting. Without a database or table, it logs a warning and moves on.

## Install

```ruby
# Gemfile
gem "env_bro", git: "https://github.com/rubydevro/env_bro.git"
```

```sh
bin/rails generate env_bro:install   # initializer, route, migration (--mount-path=/admin/env)
bin/rails db:migrate
```

The generator wraps Rails' built-in `bin/rails env_bro:install:migrations`. Use that task on its own
to pick up new migrations after upgrading the gem.

Then set the permissions in `config/initializers/env_bro.rb`. Everything is denied by default:

```ruby
EnvBro.configure do |config|
  # Who may do what. Each lambda gets the current user.
  config.can_propose = ->(user) { user.developer? }
  config.can_review  = ->(user) { user.admin? }
  config.can_reveal  = ->(user) { user.admin? }

  # Defaults shown:
  # config.parent_controller = "::ApplicationController"   # gives access to your auth
  # config.current_user = ->(controller) { controller.send(:current_user) }
  # config.user_label = ->(user) { user.email }
  # config.require_ssl = Rails.env.production?
  # config.metadata_key = "env_bro"
  # config.track_deployments = true
end
```

## One environment per deployment

EnvBro uses `Rails.application.credentials`, so it finds the file and key exactly like Rails does
(`config/credentials/<env>.yml.enc`, `RAILS_MASTER_KEY`, `config.credentials.content_path`, ...).
Each deployment holds only its own key, so to change staging credentials, use EnvBro on staging.

If the server can't decrypt its own file (missing file, missing key or wrong key), EnvBro shows
what's wrong instead of the forms.

## Security notes

- **Transport:** new values pass through the user's browser and your server. HTTPS is required in
  production. `secret_value` and the uploaded files are added to `filter_parameters`.
- **Caching:** all EnvBro pages are sent with `Cache-Control: no-store`.
- **Replay:** a contributor can't forge a file without the key, but they can commit an older valid one.
  The review diff catches this, so make review mandatory with CODEOWNERS on `config/credentials/*.yml.enc`.
- **Reveal:** during review the encrypted files travel back with the reveal form, so the server never stores uploads.
- **CSP:** the UI uses inline CSS and JS with your CSP nonce. There are no external assets.

## Known limitations

- Comments and formatting in the credentials YAML are lost when a file is rebuilt, because it is
  re-serialized from parsed data. The values themselves are preserved.
- New values are always stored as strings.

## Development

```sh
bundle install
bin/rails test                      # unit + integration tests
cd test/dummy && bin/rails s        # http://localhost:3000
```

The dummy app comes with sample `development` and `test` credentials and keys in
`test/dummy/config/credentials/`. Those keys are for testing only. Switch the fake user from the
home page, or append `?as=viewer|developer|admin` to any URL:

- `viewer`: no access
- `developer`: can propose changes
- `admin`: can propose, review and reveal values

To try the full flow:

1. As a developer, propose a change and download the file.
2. As an admin, review that file.

To check the stale-base warning, upload a different proposal as the base file.

## License

MIT. Built by [Ruby Dev SRL](https://www.rubydev.ro).
