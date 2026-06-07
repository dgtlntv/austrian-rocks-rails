class WalkingPathGeojsonParser
  Result = Data.define(:geometry, :error) do
    def success?
      error.nil?
    end
  end

  def self.parse(input)
    new(input).parse
  end

  def initialize(input)
    @input = input.to_s
  end

  def parse
    return failure("GeoJSON is required") if @input.blank?

    decoded = decode_json
    return decoded unless decoded.success?

    line_geometries = extract_line_geometries(decoded.geometry)
    return failure("GeoJSON must contain a LineString or MultiLineString") if line_geometries.empty?
    return failure("GeoJSON must contain exactly one LineString or MultiLineString") if line_geometries.many?

    geometry = line_geometries.first
    return failure("GeoJSON line geometry is empty") if geometry.empty?

    Result.new(geometry: geometry, error: nil)
  rescue RGeo::Error::InvalidGeometry
    failure("GeoJSON contains invalid line geometry")
  end

  private

  # Walking paths are editorial source records, so one admin form submission must map
  # to exactly one persisted path. Rejecting unsupported shapes and multi-line feature
  # collections here keeps invalid GeoJSON from partially updating the model.
  def extract_line_geometries(entity)
    case entity
    when RGeo::Feature::LineString, RGeo::Feature::MultiLineString
      [ entity ]
    when RGeo::GeoJSON::Feature
      extract_line_geometries(entity.geometry)
    when RGeo::GeoJSON::FeatureCollection
      entity.map { |feature| extract_line_geometries(feature) }.flatten
    else
      []
    end
  end

  def decode_json
    Result.new(geometry: RGeo::GeoJSON.decode(@input, geo_factory: FACTORY), error: nil)
  rescue JSON::ParserError
    failure("GeoJSON is malformed JSON")
  rescue RGeo::Error::ParseError
    failure("GeoJSON could not be decoded")
  end

  def failure(message)
    Result.new(geometry: nil, error: message)
  end
end
