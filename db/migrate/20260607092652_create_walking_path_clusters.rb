class CreateWalkingPathClusters < ActiveRecord::Migration[8.0]
  def change
    create_table :walking_path_clusters do |t|
      t.references :walking_path, null: false, foreign_key: true
      t.references :cluster, null: false, foreign_key: true

      t.timestamps

      t.index [ :walking_path_id, :cluster_id ], unique: true
    end
  end
end
