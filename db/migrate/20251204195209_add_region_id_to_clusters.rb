class AddRegionIdToClusters < ActiveRecord::Migration[8.0]
  def change
    add_column :clusters, :region_id, :integer
  end
end
