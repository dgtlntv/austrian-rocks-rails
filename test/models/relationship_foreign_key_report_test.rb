require "test_helper"

class RelationshipForeignKeyReportTest < ActiveSupport::TestCase
  test "reports clean and deferred candidate relationships" do
    connection = ActiveRecord::Base.connection
    connection.create_table(:fk_report_targets, temporary: true) { |t| t.string :name }
    connection.create_table(:fk_report_sources, temporary: true) { |t| t.bigint :target_id }
    connection.execute("INSERT INTO fk_report_targets (id, name) VALUES (1, 'target')")
    connection.execute("INSERT INTO fk_report_sources (id, target_id) VALUES (1, 1), (2, 99), (3, NULL)")

    report = RelationshipForeignKeyReport.report(candidates: [
      { table: "fk_report_sources", column: "target_id", target_table: "fk_report_targets" }
    ])

    assert_equal "deferred", report.first[:status]
    assert_equal 1, report.first[:count]
    assert_equal [ 2 ], report.first[:row_ids].map(&:to_i)
  ensure
    connection&.drop_table(:fk_report_sources, if_exists: true)
    connection&.drop_table(:fk_report_targets, if_exists: true)
  end

  test "default candidate list includes topo boulder relationship" do
    candidate = RelationshipForeignKeyReport::CANDIDATES.find do |entry|
      entry[:table] == "topos" && entry[:column] == "boulder_id" && entry[:target_table] == "boulders"
    end

    assert candidate
  end
end
