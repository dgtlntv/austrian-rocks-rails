class RenameDescriptionFrToDescriptionDe < ActiveRecord::Migration[8.0]
  def change
    rename_column :areas, :description_fr, :description_de
    rename_column :areas, :warning_fr, :warning_de
  end
end
