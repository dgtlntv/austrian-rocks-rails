class Problem < ApplicationRecord
  include PgSearchable

  init_pg_searchable

  belongs_to :area
  has_many :lines, dependent: :destroy
  has_many :topos, through: :lines
  has_many :children, class_name: "Problem", foreign_key: "parent_id"
  belongs_to :parent, class_name: "Problem", optional: true
  belongs_to :bleau_problem, foreign_key: "bleau_info_id", optional: true
  has_many :contribution_requests
  has_many :contributions

  audited except: [ :has_line, :ascents, :ratings, :ratings_average, :popularity, :featured ], associated_with: :import
  attr_accessor :import # used by audited associated_with: :import
  include CheckConflicts

  STEEPNESS_VALUES = %w[wall slab overhang roof traverse other]
  GRADE_VALUES = %w[
    1a 1a/+ 1a+ 1b 1b/+ 1b+ 1c 1c/+ 1c+
    2a 2a/+ 2a+ 2b 2b/+ 2b+ 2c 2c/+ 2c+
    3a 3a/+ 3a+ 3b 3b/+ 3b+ 3c 3c/+ 3c+
    4a 4a/+ 4a+ 4b 4b/+ 4b+ 4c 4c/+ 4c+
    5a 5a/+ 5a+ 5b 5b/+ 5b+ 5c 5c/+ 5c+
    6a 6a/+ 6a+ 6b 6b/+ 6b+ 6c 6c/+ 6c+
    7a 7a/+ 7a+ 7b 7b/+ 7b+ 7c 7c/+ 7c+
    8a 8a/+ 8a+ 8b 8b/+ 8b+ 8c 8c/+ 8c+
    9a 9a/+ 9a+ 9b 9b/+ 9b+ 9c 9c/+ 9c+
  ]
  LANDING_VALUES = %w[easy medium hard]
  normalizes :name, with: ->(s) { s.strip.presence }

  validates :steepness, inclusion: { in: STEEPNESS_VALUES }
  validates :grade, inclusion: { in: GRADE_VALUES }, allow_blank: true
  validates :landing, inclusion: { in: LANDING_VALUES }, allow_blank: true
  validates :bleau_info_id, uniqueness: true, allow_blank: true
  validate :validate_parent

  scope :level, ->(i) { where("grade >= ? AND grade < ?", "#{i}a", "#{i + 1}a").tap { raise unless i.in?(1..8) } }
  scope :significant_ascents, -> { where("ascents >= ?", 20) }
  scope :with_location, -> { where.not(location: nil) }
  scope :without_location, -> { where(location: nil) }
  scope :with_line, -> { where(has_line: true) }
  scope :without_line, -> { where(has_line: false) }
  scope :without_line_only, -> { where(has_line: false).with_location }
  scope :complete, -> { where(has_line: true).with_location }
  scope :incomplete, -> { where("problems.has_line = FALSE OR problems.location IS NULL") }
  scope :without_contribution_request, -> { left_joins(:contribution_requests).where(contribution_requests: { id: nil }) }
  scope :with_unpublished, ->(include_unpublished = false) { include_unpublished ? all : joins(:area).where(areas: { published: true }).where.not(location: nil) }

  def geolocation
    { lat: location&.lat || 0.0, lng: location&.lon || 0.0 }
  end

  def area_name
    area.name
  end

  def published?
    area.published && location.present?
  end

  def to_param
    [ id, name&.parameterize ].compact.join("-")
  end

  def name_with_fallback
    name.present? ? name : I18n.t("problem.no_name")
  end

  def name_debug
    name
  end

  def variants
    if parent
      [ parent ] + parent.children - [ self ]
    else
      children
    end
  end

  # # FIXME: document & test
  # def risk_score
  #   return nil unless height && landing

  #   # FIXME: use a default value
  #   mapping = { "easy" => 0, "medium" => 3, "hard" => 10 }

  #   (mapping[landing] * [(height - 2), 0].max).round(1)
  # end


  def update_has_line
    update(has_line: lines.published.with_coordinates.any?)
  end

  private

  def validate_parent
    if parent_id && parent_id == id
      errors.add(:parent_id, "cannot be equal to problem_id")
    end

    if parent && parent.area_id != area_id
      errors.add(:parent_id, "cannot have a different area_id")
    end

    if parent && parent.parent_id
      errors.add(:parent_id, "cannot be a parent itself")
    end
  end
end
