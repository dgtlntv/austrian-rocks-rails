class AddNameToBoulders < ActiveRecord::Migration[8.0]
  def change
    add_column :boulders, :name, :string
  end
end
