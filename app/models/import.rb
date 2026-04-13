class Import < ApplicationRecord
  has_one_attached :file
  has_associated_audits

  def applied?
    applied_at.present?
  end

  def objects_to_update
    ImportParser.new(RGeo::GeoJSON.decode(file.download)).objects_to_update
  end
end

class ImportParser
  def initialize(features)
    @features = features.to_a
    @objects = []
    @area_id = infer_area_id
  end

  def objects_to_update
    parse_problems
    parse_boulders
    parse_clusters
    parse_regions

    @objects
  end

  def parse_problems
    problem_features.each do |feature|
      if feature["problemId"].present?
        problem = Problem.find(feature["problemId"])
      else
        raise "All problems must have a `problemId` property"
      end

      if problem.location.present? && feature["updatedAt"].present?
        problem.conflicting_updated_at = true if problem.updated_at.to_s != feature["updatedAt"]
      end

      problem.assign_attributes(
        location: FACTORY.point(feature.geometry.x, feature.geometry.y)
      )

      @objects << problem if problem.changes.any?
    end
  end

  def parse_boulders
    boulder_features.each do |feature|
      # some editors use LineString and some use Polygon => we need to handle both
      line_string = case feature.geometry
      when ::RGeo::Feature::LineString
        feature.geometry
      when ::RGeo::Feature::Polygon
        FACTORY.line_string(feature.geometry.exterior_ring.points)
      end

      polygon = FACTORY.polygon(line_string)

      if feature["boulderId"].present?
        boulder = Boulder.find(feature["boulderId"])
      else
        if existing_boulder = Boulder.where(polygon: polygon).first
          boulder = existing_boulder
        else
          boulder = Boulder.new(area_id: @area_id)
        end
      end

      boulder.conflicting_updated_at = true if boulder.persisted? && boulder.updated_at.to_s != feature["updatedAt"]

      boulder.assign_attributes(
        polygon: polygon,
        name: feature["name"]
      )

      @objects << boulder if boulder.changes.any?
    end
  end

  private

  def infer_area_id
    # If we only have cluster or region features, area_id is not needed
    return nil if problem_features.empty? && boulder_features.empty? && (cluster_features.any? || region_features.any?)

    problems = problem_features.map { |feature| Problem.find_by(id: feature["problemId"]) }
    boulders = boulder_features.map { |feature| Boulder.find_by(id: feature["boulderId"]) }

    ids = (problems + boulders).compact.map(&:area_id).uniq

    raise "All features must have the same area_id" if ids.count > 1
    raise "Couldn't infer area_id" if ids.count == 0
    ids.first
  end

  def problem_features
    @problem_features ||= @features.select { |f| f.geometry.geometry_type == ::RGeo::Feature::Point }
  end

  # some editors use LineString and some use Polygon => we need to handle both
  def boulder_features
    @boulder_features ||= @features.select { |f|
      f.geometry.geometry_type.in?([ ::RGeo::Feature::LineString, ::RGeo::Feature::Polygon ]) &&
      f["boulderId"].present?
    }
  end

  def cluster_features
    @cluster_features ||= @features.select { |f|
      f.geometry.geometry_type == ::RGeo::Feature::Polygon &&
      f["clusterId"].present?
    }
  end

  def region_features
    @region_features ||= @features.select { |f|
      f.geometry.geometry_type == ::RGeo::Feature::Polygon &&
      f["regionId"].present?
    }
  end

  def parse_clusters
    cluster_features.each do |feature|
      cluster = Cluster.find(feature["clusterId"])

      # Detect conflicts - only check if updatedAt is present in the feature
      if cluster.persisted? && feature["updatedAt"].present?
        cluster.conflicting_updated_at = true if cluster.updated_at.to_s != feature["updatedAt"]
      end

      # Extract rectangle corners from polygon
      polygon = feature.geometry
      points = polygon.exterior_ring.points

      # Get bounding box from rectangle
      # Handle both Cartesian (x/y) and Geographic (lon/lat) points
      lons = points.map { |p| p.respond_to?(:lon) ? p.lon : p.x }
      lats = points.map { |p| p.respond_to?(:lat) ? p.lat : p.y }

      sw = FACTORY.point(lons.min, lats.min)
      ne = FACTORY.point(lons.max, lats.max)
      center = FACTORY.point(
        (lons.min + lons.max) / 2,
        (lats.min + lats.max) / 2
      )

      cluster.assign_attributes(
        sw: sw,
        ne: ne,
        center: center,
        name: feature["name"]
      )

      @objects << cluster if cluster.changes.any?
    end
  end

  def parse_regions
    region_features.each do |feature|
      region = Region.find(feature["regionId"])

      # Detect conflicts - only check if updatedAt is present in the feature
      if region.persisted? && feature["updatedAt"].present?
        region.conflicting_updated_at = true if region.updated_at.to_s != feature["updatedAt"]
      end

      # Extract rectangle corners from polygon
      polygon = feature.geometry
      points = polygon.exterior_ring.points

      # Get bounding box from rectangle
      # Handle both Cartesian (x/y) and Geographic (lon/lat) points
      lons = points.map { |p| p.respond_to?(:lon) ? p.lon : p.x }
      lats = points.map { |p| p.respond_to?(:lat) ? p.lat : p.y }

      sw = FACTORY.point(lons.min, lats.min)
      ne = FACTORY.point(lons.max, lats.max)
      center = FACTORY.point(
        (lons.min + lons.max) / 2,
        (lats.min + lats.max) / 2
      )

      region.assign_attributes(
        sw: sw,
        ne: ne,
        center: center,
        name: feature["name"]
      )

      @objects << region if region.changes.any?
    end
  end
end
