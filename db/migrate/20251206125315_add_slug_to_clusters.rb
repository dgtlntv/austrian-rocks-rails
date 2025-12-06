class AddSlugToClusters < ActiveRecord::Migration[8.0]
  def change
    add_column :clusters, :slug, :string
  end
end
