class CreateGuidebooks < ActiveRecord::Migration[8.0]
  def change
    create_table :guidebooks do |t|
      t.string :title, null: false
      t.string :author
      t.string :url, null: false

      t.timestamps
    end
  end
end
