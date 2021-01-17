class JiraUtil
  class Report < Base
    attr_reader :sprint

    def initialize(report, sprint)
      super(report)
      @sprint = sprint
    end

    def issues
      return @issues unless @issues.nil?

      @issues = (@report.completedIssues + @report.issuesNotCompletedInCurrentSprint).map do |issue|
        Issue.new(issue, self)
      end
    end

    def resolved_points
      issues.reject(&:unburnable?).sum(&:resolved_point)
    end

    def interrupted_points
      issues.reject(&:unburnable?).select(&:interrupted?).sum(&:resolved_point)
    end

    def progress_points
      resolved_points - interrupted_points
    end
  end
end
