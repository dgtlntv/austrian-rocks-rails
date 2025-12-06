class AddCoverAndTagsToRegions < ActiveRecord::Migration[8.0]
  def change
    add_column :regions, :tags, :string, array: true, default: [], null: false
    add_column :regions, :published, :boolean, default: true, null: false
    add_index :regions, :tags, using: :gin
  end
end
