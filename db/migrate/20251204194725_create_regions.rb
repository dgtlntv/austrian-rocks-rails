class CreateRegions < ActiveRecord::Migration[8.0]
  def change
    create_table :regions do |t|
      t.string :name
      t.integer :main_cluster_id
      t.st_point :center, geographic: true, srid: 4326
      t.st_point :sw, geographic: true, srid: 4326
      t.st_point :ne, geographic: true, srid: 4326

      t.timestamps
    end
  end
end
