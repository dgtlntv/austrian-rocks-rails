namespace :problem_boulder_assignments do
  desc "Report deterministic problem-to-boulder assignment categories"
  task report: :environment do
    report = ProblemBoulderAssignment.report
    print_problem_boulder_assignment_report(report)
  end

  desc "Backfill problems.boulder_id for unambiguous problem-to-boulder matches"
  task backfill: :environment do
    report = ProblemBoulderAssignment.report
    print_problem_boulder_assignment_report(report)

    result = ProblemBoulderAssignment.backfill(Problem.all, report)
    puts "updated: #{result[:updated_ids].length}"
    puts "updated_ids: #{format_ids(result[:updated_ids])}"
  end

  def print_problem_boulder_assignment_report(report)
    ProblemBoulderAssignment::CATEGORIES.each do |category|
      ids = report[:categories][category]
      puts "#{category}: #{ids.length}"
      puts "#{category}_ids: #{format_ids(ids)}"
    end
  end

  def format_ids(ids)
    ids.present? ? ids.join(",") : "none"
  end
end
