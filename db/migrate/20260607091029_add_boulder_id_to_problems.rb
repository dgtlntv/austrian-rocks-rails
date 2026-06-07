class AddBoulderIdToProblems < ActiveRecord::Migration[8.0]
  def change
    add_reference :problems, :boulder, null: true, foreign_key: true
  end
end
