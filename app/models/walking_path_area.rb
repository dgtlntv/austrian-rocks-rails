class WalkingPathArea < ApplicationRecord
  belongs_to :walking_path
  belongs_to :area

  validates :area_id, uniqueness: { scope: :walking_path_id }
end
