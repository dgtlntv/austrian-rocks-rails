class Cluster < ApplicationRecord
  include CheckConflicts

  has_many :areas
end
