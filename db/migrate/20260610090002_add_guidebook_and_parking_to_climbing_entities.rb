class AddGuidebookAndParkingToClimbingEntities < ActiveRecord::Migration[8.0]
  def change
    %i[regions clusters areas].each do |table|
      add_reference table, :guidebook, foreign_key: true, null: true
      add_reference table, :parking_poi, foreign_key: { to_table: :pois }, null: true
    end
  end
end
