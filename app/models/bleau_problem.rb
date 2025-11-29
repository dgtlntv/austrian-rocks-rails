class BleauProblem < ApplicationRecord
  belongs_to :bleau_area, optional: true
  has_one :problem, foreign_key: "bleau_info_id"

  # TODO: make DRY with problem.rb
  validates :steepness, inclusion: { in: Problem::STEEPNESS_VALUES }
  validates :grade, inclusion: { in: Problem::GRADE_VALUES }, allow_blank: true

  normalizes :name, with: ->(s) { s.strip.gsub(/\A-\z/, "").presence }

  def name_with_fallback
    if name.present?
      name
    else
      I18n.t("problem.no_name")
    end
  end
end
