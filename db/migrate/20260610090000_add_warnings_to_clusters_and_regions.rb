class AddWarningsToClustersAndRegions < ActiveRecord::Migration[8.0]
  def change
    add_column :clusters, :warning_de, :text
    add_column :clusters, :warning_en, :text
    add_column :regions, :warning_de, :text
    add_column :regions, :warning_en, :text
  end
end
