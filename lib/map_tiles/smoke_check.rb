# frozen_string_literal: true

require "json"
require "stringio"
require "zlib"
require "map_tiles/configuration"

module MapTiles
  class SmokeCheck
    class Error < StandardError; end

    AUSTRIA_BOUNDS = {
      min_lon: 9.0,
      max_lon: 17.5,
      min_lat: 46.0,
      max_lat: 49.5
    }.freeze

    SCALAR_VALUE_CLASSES = [ String, Integer, Float, TrueClass, FalseClass ].freeze
    PMTILES_MAGIC = "PMTiles"
    PMTILES_HEADER_BYTES = 127
    PMTILES_VERSION = 3
    PMTILES_METADATA_OFFSET = 24
    PMTILES_METADATA_LENGTH_OFFSET = 32
    PMTILES_INTERNAL_COMPRESSION_OFFSET = 97
    PMTILES_COMPRESSION_NONE = 1
    PMTILES_COMPRESSION_GZIP = 2
    ALLOWED_URL_FIELDS = %w[coverPhotoUrl googleUrl guidebookUrl parkingGoogleUrl topoPhotoUrl].freeze

    attr_reader :configuration, :argv, :out, :mode, :allowed_empty_layers

    def initialize(configuration: Configuration.new, argv: [], out: $stdout)
      @configuration = configuration
      @argv = argv.dup
      @out = out
      @mode = "production"
      @allowed_empty_layers = []
      parse_options!
    end

    def run
      result = check
      print_summary(result)
      result
    end

    def check
      failures = []
      verify_artifact!(failures)
      metadata = read_pmtiles_metadata(failures)

      layer_results = LayerContract.layers.map do |layer|
        inspect_geojson_layer(layer, failures)
      end

      verify_metadata!(metadata, layer_results, failures)
      verify_layer_counts!(layer_results, failures)
      bounds = combined_bounds(layer_results)
      verify_bounds!(bounds, failures)

      raise Error, failures.join("\n") if failures.any?

      {
        mode: mode,
        layers: layer_results,
        bounds: bounds
      }
    end

    private

    def parse_options!
      until argv.empty?
        option = argv.shift

        case option
        when /\A--mode=(.+)\z/
          @mode = Regexp.last_match(1)
        when "--mode"
          @mode = argv.shift.to_s
        when /\A--allow-empty=(.*)\z/
          @allowed_empty_layers = split_layer_list(Regexp.last_match(1))
        when "--allow-empty"
          @allowed_empty_layers = split_layer_list(argv.shift.to_s)
        else
          raise Error, "Unknown smoke-check option: #{option}"
        end
      end

      raise Error, "Smoke-check mode must be production or relaxed" unless %w[production relaxed].include?(mode)

      unknown_layers = allowed_empty_layers - LayerContract.layer_names
      raise Error, "Unknown --allow-empty layer(s): #{unknown_layers.join(', ')}" if unknown_layers.any?
    end

    def split_layer_list(value)
      value.split(",").map(&:strip).reject(&:empty?)
    end

    def verify_artifact!(failures)
      artifact_path = configuration.artifact_path

      unless artifact_path.exist?
        failures << "PMTiles artifact is missing: #{artifact_path}"
        return
      end

      failures << "PMTiles artifact is empty: #{artifact_path}" unless artifact_path.size.positive?
    end

    def read_pmtiles_metadata(failures)
      artifact_path = configuration.artifact_path
      return unless artifact_path.exist? && artifact_path.size.positive?

      metadata_json = read_pmtiles_metadata_json(artifact_path, failures)
      return if metadata_json.blank?

      JSON.parse(metadata_json)
    rescue JSON::ParserError => e
      failures << "PMTiles artifact metadata is invalid JSON: #{artifact_path} (#{e.message})"
      nil
    end

    def read_pmtiles_metadata_json(artifact_path, failures)
      File.open(artifact_path, "rb") do |file|
        header = file.read(PMTILES_HEADER_BYTES)
        unless valid_pmtiles_header?(header)
          failures << "PMTiles artifact is not a valid PMTiles v#{PMTILES_VERSION} archive: #{artifact_path}"
          return
        end

        metadata_offset = read_uint64(header, PMTILES_METADATA_OFFSET)
        metadata_length = read_uint64(header, PMTILES_METADATA_LENGTH_OFFSET)
        internal_compression = header.getbyte(PMTILES_INTERNAL_COMPRESSION_OFFSET)

        if metadata_length.zero?
          failures << "PMTiles artifact metadata is empty: #{artifact_path}"
          return
        end

        file.seek(metadata_offset)
        metadata_blob = file.read(metadata_length)
        unless metadata_blob&.bytesize == metadata_length
          failures << "PMTiles artifact metadata could not be read from #{artifact_path}"
          return
        end

        decompress_pmtiles_metadata(metadata_blob, internal_compression, artifact_path, failures)
      end
    rescue SystemCallError => e
      failures << "PMTiles artifact metadata could not be read from #{artifact_path} (#{e.message})"
      nil
    end

    def valid_pmtiles_header?(header)
      header&.bytesize == PMTILES_HEADER_BYTES &&
        header.start_with?(PMTILES_MAGIC) &&
        header.getbyte(PMTILES_MAGIC.bytesize) == PMTILES_VERSION
    end

    def read_uint64(header, offset)
      header.byteslice(offset, 8).unpack1("Q<")
    end

    def decompress_pmtiles_metadata(metadata_blob, internal_compression, artifact_path, failures)
      case internal_compression
      when PMTILES_COMPRESSION_NONE
        metadata_blob
      when PMTILES_COMPRESSION_GZIP
        Zlib::GzipReader.wrap(StringIO.new(metadata_blob), &:read)
      else
        failures << "PMTiles artifact metadata uses unsupported internal compression #{internal_compression}: #{artifact_path}"
        nil
      end
    rescue Zlib::Error => e
      failures << "PMTiles artifact metadata could not be decompressed from #{artifact_path} (#{e.message})"
      nil
    end

    def verify_metadata!(metadata, layer_results, failures)
      return if metadata.blank?

      vector_layers = metadata.fetch("vector_layers", nil)
      unless vector_layers.is_a?(Array)
        failures << "PMTiles metadata must contain a vector_layers array"
        return
      end

      actual_layer_names = vector_layers.map { |layer| layer["id"] || layer["name"] }.compact
      layer_counts = layer_results.to_h { |result| [ result.fetch(:name), result.fetch(:count) ] }
      required_layer_names = LayerContract.layer_names - production_optional_layer_names
      dataful_optional_layer_names = production_optional_layer_names.select { |name| layer_counts.fetch(name, 0).positive? }
      missing_layer_names = (required_layer_names + dataful_optional_layer_names).uniq - actual_layer_names
      unexpected_layer_names = actual_layer_names - LayerContract.layer_names

      if missing_layer_names.any? || unexpected_layer_names.any?
        details = []
        details << "missing #{missing_layer_names.join(', ')}" if missing_layer_names.any?
        details << "unexpected #{unexpected_layer_names.join(', ')}" if unexpected_layer_names.any?
        failures << "PMTiles metadata layers mismatch: #{details.join('; ')}"
      end

      vector_layers.each do |metadata_layer|
        layer_name = metadata_layer["id"] || metadata_layer["name"]
        contract_layer = LayerContract.layers.find { |layer| layer.name == layer_name }
        next if contract_layer.blank?

        actual_fields = metadata_field_names(metadata_layer)
        missing_required = contract_layer.required_properties - actual_fields
        unexpected_fields = actual_fields - contract_layer.properties
        if missing_required.any? || unexpected_fields.any?
          details = []
          details << "missing required fields: #{missing_required.join(', ')}" if missing_required.any?
          details << "unexpected fields: #{unexpected_fields.join(', ')}" if unexpected_fields.any?
          failures << "PMTiles metadata fields mismatch for #{contract_layer.name}: #{details.join('; ')}"
        end

        actual_fields.each do |field|
          failures << "PMTiles metadata layer #{contract_layer.name} has forbidden circuit field: #{field}" if field.match?(/circuit/i)
          failures << "PMTiles metadata layer #{contract_layer.name} has forbidden app URL field: #{field}" if forbidden_url_field?(field)
        end
      end
    end

    def forbidden_url_field?(field)
      field.match?(/url/i) && !ALLOWED_URL_FIELDS.include?(field)
    end

    def metadata_field_names(metadata_layer)
      fields = metadata_layer.fetch("fields", {})

      case fields
      when Hash
        fields.keys.sort
      when Array
        fields.sort
      else
        []
      end
    end

    def inspect_geojson_layer(layer, failures)
      path = configuration.geojson_dir.join("#{layer.name}.geojson")
      layer_result = { name: layer.name, path: path, count: 0, bounds: nil }

      unless path.exist?
        failures << "GeoJSON layer file is missing for #{layer.name}: #{path}"
        return layer_result
      end

      collection = JSON.parse(path.read)
      unless collection["type"] == "FeatureCollection" && collection["features"].is_a?(Array)
        failures << "GeoJSON layer #{layer.name} must be a FeatureCollection"
        return layer_result
      end

      features = collection.fetch("features")
      layer_result[:count] = features.length
      all_positions = []

      features.each_with_index do |feature, index|
        properties = feature.fetch("properties", {}) || {}
        geometry = feature.fetch("geometry", nil)

        verify_feature_geometry!(layer, geometry, index, failures)
        all_positions.concat(positions_for_geometry(geometry)) if geometry.present?
        verify_feature_properties!(layer, properties, index, failures)
      end

      layer_result[:bounds] = bounds_for_positions(all_positions)
      layer_result
    rescue JSON::ParserError => e
      failures << "GeoJSON layer #{layer.name} is invalid JSON: #{path} (#{e.message})"
      layer_result
    end

    def verify_feature_geometry!(layer, geometry, index, failures)
      unless geometry.is_a?(Hash) && geometry["type"].present?
        failures << "GeoJSON layer #{layer.name} feature #{index} is missing geometry"
        return
      end

      allowed_geometry_types = layer.geometry_type.split("/")
      return if allowed_geometry_types.include?(geometry.fetch("type"))

      failures << "GeoJSON layer #{layer.name} feature #{index} geometry #{geometry.fetch('type')} does not match #{layer.geometry_type}"
    end

    def verify_feature_properties!(layer, properties, index, failures)
      unless properties.is_a?(Hash)
        failures << "GeoJSON layer #{layer.name} feature #{index} properties must be an object"
        return
      end

      missing_required = layer.required_properties.reject { |property| properties.key?(property) }
      if missing_required.any?
        failures << "GeoJSON layer #{layer.name} feature #{index} is missing required properties: #{missing_required.join(', ')}"
      end

      unexpected_properties = properties.keys - layer.properties
      if unexpected_properties.any?
        failures << "GeoJSON layer #{layer.name} feature #{index} has unexpected properties: #{unexpected_properties.join(', ')}"
      end

      properties.each do |key, value|
        failures << "GeoJSON layer #{layer.name} feature #{index} has forbidden circuit field: #{key}" if key.match?(/circuit/i)
        failures << "GeoJSON layer #{layer.name} feature #{index} has forbidden app URL field: #{key}" if forbidden_url_field?(key)

        next if value.nil? || SCALAR_VALUE_CLASSES.any? { |klass| value.is_a?(klass) }

        failures << "GeoJSON layer #{layer.name} feature #{index} property #{key} is not scalar: #{value.class}"
      end
    end

    def verify_layer_counts!(layer_results, failures)
      layer_results.each do |result|
        next if result[:count].positive?

        if mode == "production"
          next if production_optional_layer_names.include?(result[:name])

          failures << "GeoJSON layer #{result[:name]} has zero features in production mode"
        elsif !allowed_empty_layers.include?(result[:name])
          failures << "GeoJSON layer #{result[:name]} has zero features but is not listed in --allow-empty"
        end
      end
    end

    def production_optional_layer_names
      return [] unless mode == "production"

      configuration.optional_production_layers
    end

    def combined_bounds(layer_results)
      bounds_for_positions(layer_results.filter_map { |result| result[:bounds] }.flat_map do |bounds|
        [ [ bounds[:min_lon], bounds[:min_lat] ], [ bounds[:max_lon], bounds[:max_lat] ] ]
      end)
    end

    def verify_bounds!(bounds, failures)
      return if bounds.blank?

      if bounds[:min_lon] < AUSTRIA_BOUNDS[:min_lon] || bounds[:max_lon] > AUSTRIA_BOUNDS[:max_lon] ||
          bounds[:min_lat] < AUSTRIA_BOUNDS[:min_lat] || bounds[:max_lat] > AUSTRIA_BOUNDS[:max_lat]
        failures << "Combined GeoJSON bounds are outside sane Austria bounds: lon #{bounds[:min_lon]}..#{bounds[:max_lon]}, lat #{bounds[:min_lat]}..#{bounds[:max_lat]}"
      end
    end

    def positions_for_geometry(geometry)
      return [] if geometry.blank?

      positions_from_coordinates(geometry.fetch("coordinates", []))
    end

    def positions_from_coordinates(coordinates)
      return [] unless coordinates.is_a?(Array)

      if coordinates.length >= 2 && coordinates[0].is_a?(Numeric) && coordinates[1].is_a?(Numeric)
        return [ coordinates ]
      end

      coordinates.flat_map { |child| positions_from_coordinates(child) }
    end

    def bounds_for_positions(positions)
      return if positions.blank?

      longitudes = positions.map { |position| position[0].to_f }
      latitudes = positions.map { |position| position[1].to_f }

      {
        min_lon: longitudes.min,
        max_lon: longitudes.max,
        min_lat: latitudes.min,
        max_lat: latitudes.max
      }
    end

    def print_summary(result)
      out.puts "PMTiles smoke check passed (mode=#{result.fetch(:mode)})"
      result.fetch(:layers).each do |layer_result|
        out.puts "#{layer_result.fetch(:name)}: #{layer_result.fetch(:count)} feature(s)"
      end

      bounds = result.fetch(:bounds)
      if bounds.present?
        out.puts "bounds: lon #{bounds[:min_lon]}..#{bounds[:max_lon]}, lat #{bounds[:min_lat]}..#{bounds[:max_lat]}"
      else
        out.puts "bounds: no features"
      end
    end
  end
end
