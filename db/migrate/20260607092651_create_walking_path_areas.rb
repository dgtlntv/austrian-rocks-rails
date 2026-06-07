class CreateWalkingPathAreas < ActiveRecord::Migration[8.0]
  def change
    create_table :walking_path_areas do |t|
      t.references :walking_path, null: false, foreign_key: true
      t.references :area, null: false, foreign_key: true

      t.timestamps

      t.index [ :walking_path_id, :area_id ], unique: true
    end
  end
end
