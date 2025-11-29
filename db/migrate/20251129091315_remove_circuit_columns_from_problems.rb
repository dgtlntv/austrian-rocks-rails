class RemoveCircuitColumnsFromProblems < ActiveRecord::Migration[8.0]
  def change
    remove_column :problems, :circuit_id, :bigint
    remove_column :problems, :circuit_number, :string
    remove_column :problems, :circuit_letter, :string
  end
end
