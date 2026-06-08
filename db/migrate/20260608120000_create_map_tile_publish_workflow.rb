# frozen_string_literal: true

class CreateMapTilePublishWorkflow < ActiveRecord::Migration[8.0]
  def change
    create_table :map_tile_publish_states do |t|
      t.datetime :stale_at, precision: nil
      t.bigint :pending_automatic_attempt_id
      t.bigint :running_attempt_id
      t.bigint :last_successful_attempt_id
      t.bigint :last_failed_attempt_id
      t.datetime :last_source_change_at, precision: nil
      t.timestamps
    end

    add_index :map_tile_publish_states, :pending_automatic_attempt_id, name: "idx_map_tile_publish_states_on_pending_automatic_attempt_id"
    add_index :map_tile_publish_states, :running_attempt_id, name: "idx_map_tile_publish_states_on_running_attempt_id"
    add_index :map_tile_publish_states, :last_successful_attempt_id, name: "idx_map_tile_publish_states_on_last_successful_attempt_id"
    add_index :map_tile_publish_states, :last_failed_attempt_id, name: "idx_map_tile_publish_states_on_last_failed_attempt_id"

    create_table :map_tile_publish_attempts do |t|
      t.string :source, null: false
      t.string :status, null: false, default: "pending"
      t.string :trigger_reason
      t.string :version
      t.datetime :scheduled_for, precision: nil
      t.datetime :enqueued_at, precision: nil
      t.datetime :started_at, precision: nil
      t.datetime :finished_at, precision: nil
      t.string :pmtiles_url
      t.string :manifest_url
      t.string :pmtiles_object_key
      t.string :manifest_object_key
      t.text :error_text
      t.timestamps
    end

    add_index :map_tile_publish_attempts, :source
    add_index :map_tile_publish_attempts, :status
    add_index :map_tile_publish_attempts, :scheduled_for
    add_index :map_tile_publish_attempts, :created_at
    add_index :map_tile_publish_attempts, :version
  end
end
