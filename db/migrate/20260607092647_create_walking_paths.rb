class CreateWalkingPaths < ActiveRecord::Migration[8.0]
  def change
    create_table :walking_paths do |t|
      t.string :label
      t.string :slug
      t.text :description
      t.boolean :published, null: false, default: false
      t.geometry :geometry, srid: 4326

      t.timestamps
    end

    add_index :walking_paths, :slug, unique: true
    add_index :walking_paths, :geometry, using: :gist
    add_check_constraint :walking_paths,
                         "geometry IS NULL OR GeometryType(geometry::geometry) IN ('LINESTRING', 'MULTILINESTRING')",
                         name: "walking_paths_geometry_line_check"
  end
end
