class WalkingPathCluster < ApplicationRecord
  belongs_to :walking_path
  belongs_to :cluster

  validates :cluster_id, uniqueness: { scope: :walking_path_id }
end
