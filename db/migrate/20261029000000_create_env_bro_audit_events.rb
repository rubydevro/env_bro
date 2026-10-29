class CreateEnvBroAuditEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :env_bro_audit_events do |t|
      t.string :event, null: false
      t.string :user_label
      t.string :environment, null: false
      t.json :details, null: false, default: {}

      # proposal_created: the id embedded in the file's metadata and the SHA-256 of the file handed out.
      # proposal_deployed: the SHA-256 of the file found running.
      t.string :proposal_token
      t.string :file_digest

      # proposal_deployed: the proposal that went live.
      t.references :proposal, foreign_key: { to_table: :env_bro_audit_events }, index: { unique: true }

      t.datetime :created_at, null: false
    end

    add_index :env_bro_audit_events, :created_at
    add_index :env_bro_audit_events, :proposal_token
    add_index :env_bro_audit_events, :file_digest
  end
end
