class AddVerifiedRelationshipForeignKeys < ActiveRecord::Migration[8.0]
  def up
    change_column :areas, :cluster_id, :bigint
    change_column :clusters, :main_area_id, :bigint
    change_column :clusters, :region_id, :bigint
    change_column :regions, :main_cluster_id, :bigint
    change_column :topos, :boulder_id, :bigint

    add_index :areas, :cluster_id, if_not_exists: true
    add_index :clusters, :main_area_id, if_not_exists: true
    add_index :clusters, :region_id, if_not_exists: true
    add_index :regions, :main_cluster_id, if_not_exists: true
    add_index :problems, :parent_id, if_not_exists: true

    add_foreign_key :areas, :clusters, if_not_exists: true
    add_foreign_key :clusters, :areas, column: :main_area_id, if_not_exists: true
    add_foreign_key :clusters, :regions, if_not_exists: true
    add_foreign_key :regions, :clusters, column: :main_cluster_id, if_not_exists: true
    add_foreign_key :topos, :boulders, if_not_exists: true
    add_foreign_key :lines, :problems, if_not_exists: true
    add_foreign_key :lines, :topos, if_not_exists: true
    add_foreign_key :poi_routes, :areas, if_not_exists: true
    add_foreign_key :poi_routes, :pois, if_not_exists: true
    add_foreign_key :contribution_requests, :problems, if_not_exists: true
    add_foreign_key :contributions, :problems, if_not_exists: true
    add_foreign_key :problems, :problems, column: :parent_id, if_not_exists: true
  end

  def down
    remove_foreign_key :problems, column: :parent_id, if_exists: true
    remove_foreign_key :contributions, :problems, if_exists: true
    remove_foreign_key :contribution_requests, :problems, if_exists: true
    remove_foreign_key :poi_routes, :pois, if_exists: true
    remove_foreign_key :poi_routes, :areas, if_exists: true
    remove_foreign_key :lines, :topos, if_exists: true
    remove_foreign_key :lines, :problems, if_exists: true
    remove_foreign_key :topos, :boulders, if_exists: true
    remove_foreign_key :regions, column: :main_cluster_id, if_exists: true
    remove_foreign_key :clusters, :regions, if_exists: true
    remove_foreign_key :clusters, column: :main_area_id, if_exists: true
    remove_foreign_key :areas, :clusters, if_exists: true

    remove_index :problems, :parent_id, if_exists: true
    remove_index :regions, :main_cluster_id, if_exists: true
    remove_index :clusters, :region_id, if_exists: true
    remove_index :clusters, :main_area_id, if_exists: true
    remove_index :areas, :cluster_id, if_exists: true

    change_column :topos, :boulder_id, :integer
    change_column :regions, :main_cluster_id, :integer
    change_column :clusters, :region_id, :integer
    change_column :clusters, :main_area_id, :integer
    change_column :areas, :cluster_id, :integer
  end
end
