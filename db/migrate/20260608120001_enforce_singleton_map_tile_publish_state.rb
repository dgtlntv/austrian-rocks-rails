# frozen_string_literal: true

# Adds a DB-enforced singleton constraint to the map_tile_publish_states table.
# Uses a boolean `singleton` column with a partial unique index so only one
# row can have `singleton = true`, preventing duplicate state rows that would
# undermine the transaction-lock concurrency safety for PMTiles publishing.
class EnforceSingletonMapTilePublishState < ActiveRecord::Migration[8.0]
  def change
    add_column :map_tile_publish_states, :singleton, :boolean, default: true, null: false

    # Partial unique index: only one row may have singleton = true
    add_index :map_tile_publish_states, :singleton,
              unique: true,
              where: "singleton = true",
              name: "idx_map_tile_publish_states_singleton"
  end
end
