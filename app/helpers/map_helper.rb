# frozen_string_literal: true

module MapHelper
  def map_release_manifest_url
    MapTiles::Configuration.new.manifest_public_url
  end

  def map_default_style
    MapTiles::Configuration.new.default_style
  end

  # Static localized strings for the JS-rendered map info card; dynamic values
  # (height) keep their %{...} placeholder for interpolation in JS.
  def map_card_strings
    {
      show_on_map: t("views.map.card.show_on_map"),
      directions: t("views.map.card.directions"),
      guidebook: t("views.map.card.guidebook"),
      problems: t("views.map.card.problems"),
      warning: t("views.map.card.warning"),
      close: t("views.map.card.close"),
      details: t("views.map.card.details"),
      height_meters: t("views.map.card.height_meters", height: "%{height}"),
      steepness: Problem::STEEPNESS_VALUES.index_with { |value| t("problem.steepness.#{value}") },
      poi_types: Poi::TYPE_VALUES.index_with { |value| t("views.map.card.poi_types.#{value}") }
    }
  end
end
