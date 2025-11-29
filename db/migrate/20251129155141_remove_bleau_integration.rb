class RemoveBleauIntegration < ActiveRecord::Migration[8.0]
  def change
    # Drop bleau-related tables
    drop_table :bleau_problems, if_exists: true
    drop_table :bleau_areas, if_exists: true

    # Remove bleau-related columns from problems table
    remove_column :problems, :bleau_info_id, :integer, if_exists: true

    # Remove bleau-related columns from areas table
    remove_column :areas, :bleau_area_id, :integer, if_exists: true
  end
end
