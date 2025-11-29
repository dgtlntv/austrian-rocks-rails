class DropCircuitsTable < ActiveRecord::Migration[8.0]
  def change
    drop_table :circuits do |t|
      t.string "color"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.integer "risk", limit: 2
    end
  end
end
