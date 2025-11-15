require 'csv'

namespace :import do
  desc "Import problems from route-import.csv"
  task problems: :environment do
    csv_path = Rails.root.join('route-import.csv')

    unless File.exist?(csv_path)
      puts "ERROR: route-import.csv not found in #{Rails.root}"
      exit 1
    end

    # Build area lookup hash
    area_lookup = Area.all.pluck(:name, :id).to_h
    puts "Found #{area_lookup.size} areas in database"
    puts "Areas: #{area_lookup.keys.sort.join(', ')}"
    puts ""

    # Check which areas are required by the CSV
    required_areas = Set.new
    CSV.foreach(csv_path, headers: true) do |row|
      area_name = row['Area']&.strip
      required_areas.add(area_name) if area_name.present?
    end

    puts "Required areas from CSV: #{required_areas.to_a.sort.join(', ')}"
    puts ""

    # Check for missing areas
    missing_areas = required_areas.to_a - area_lookup.keys
    if missing_areas.any?
      puts "ERROR: The following areas are missing from the database:"
      missing_areas.each { |area| puts "  - #{area}" }
      puts ""
      puts "Please create these areas first before running this import."
      exit 1
    end

    puts "✓ All required areas exist in database"
    puts ""

    created_count = 0
    skipped_count = 0
    error_count = 0
    errors = []

    CSV.foreach(csv_path, headers: true) do |row|
      begin
        # Parse name - if it's a dash, leave it empty
        name = row['Name']&.strip
        name = nil if name == '-'

        # Find area by name
        area_name = row['Area']&.strip
        area_id = area_lookup[area_name]

        unless area_id
          errors << "Row #{row['ID']} (#{name || 'unnamed'}): Area '#{area_name}' not found"
          error_count += 1
          next
        end

        # Parse grade - convert to lowercase and handle "?" as empty
        grade = row['Grade']&.strip&.downcase
        grade = nil if grade.blank? || grade == '?'

        # Validate grade if present
        if grade.present? && !Problem::GRADE_VALUES.include?(grade)
          errors << "Row #{row['ID']} (#{name}): Invalid grade '#{grade}'"
          error_count += 1
          next
        end

        # Parse steepness - convert to lowercase
        steepness = row['Steepness']&.strip&.downcase

        # Validate steepness
        unless Problem::STEEPNESS_VALUES.include?(steepness)
          errors << "Row #{row['ID']} (#{name}): Invalid steepness '#{steepness}'"
          error_count += 1
          next
        end

        # Parse sit start (SD column) - convert TRUE/FALSE to boolean
        sit_start = row['SD']&.strip&.upcase == 'TRUE'

        # Create the problem
        problem = Problem.create!(
          name: name,
          area_id: area_id,
          grade: grade,
          steepness: steepness,
          sit_start: sit_start
        )

        display_name = problem.name.present? ? problem.name : "(unnamed)"
        puts "✓ Created: #{display_name} (#{area_name}) - #{grade || 'no grade'} - #{steepness} - #{sit_start ? 'SD' : 'standing'}"
        created_count += 1

      rescue ActiveRecord::RecordInvalid => e
        errors << "Row #{row['ID']} (#{name || 'unnamed'}): #{e.message}"
        error_count += 1
      rescue => e
        errors << "Row #{row['ID']} (#{name || 'unnamed'}): Unexpected error: #{e.message}"
        error_count += 1
      end
    end

    puts ""
    puts "=" * 80
    puts "IMPORT SUMMARY"
    puts "=" * 80
    puts "Created: #{created_count} problems"
    puts "Skipped: #{skipped_count} problems (no name)"
    puts "Errors:  #{error_count} problems"

    if errors.any?
      puts ""
      puts "ERRORS:"
      errors.each { |error| puts "  - #{error}" }
    end
  end
end
