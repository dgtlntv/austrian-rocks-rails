class AddGuidebookAndParkingToClimbingEntities < ActiveRecord::Migration[8.0]
  def change
    %i[regions clusters areas].each do |table|
      add_reference table, :guidebook, foreign_key: true
      add_reference table, :parking_poi, foreign_key: { to_table: :pois }
    end
  end
end
