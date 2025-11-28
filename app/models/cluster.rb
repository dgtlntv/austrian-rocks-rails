class Cluster < ApplicationRecord
  include CheckConflicts

  audited associated_with: :import
  attr_accessor :import # used by audited associated_with: :import

  has_many :areas
end
