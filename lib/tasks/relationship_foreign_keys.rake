namespace :relationship_foreign_keys do
  desc "Report dirty rows that would prevent candidate relationship foreign keys"
  task report: :environment do
    RelationshipForeignKeyReport.report.each do |entry|
      puts "#{entry[:table]}.#{entry[:column]} -> #{entry[:target_table]}.id: #{entry[:status]}"
      puts "count: #{entry[:count]}"
      puts "row_ids: #{entry[:row_ids].present? ? entry[:row_ids].join(",") : "none"}"
    end
  end
end
