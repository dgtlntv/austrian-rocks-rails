class AddDescriptionAndVideoLinksToProblems < ActiveRecord::Migration[8.0]
  def change
    add_column :problems, :description, :text
    add_column :problems, :video_links, :text, array: true, default: []
  end
end
