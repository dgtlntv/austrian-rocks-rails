class AddCoverAndTagsToClusters < ActiveRecord::Migration[8.0]
  def change
    add_column :clusters, :tags, :string, array: true, default: [], null: false
    add_column :clusters, :published, :boolean, default: true, null: false
    add_index :clusters, :tags, using: :gin
  end
end
