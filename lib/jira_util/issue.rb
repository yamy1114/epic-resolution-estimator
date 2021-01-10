class JiraUtil
  class Issue < Base
    module Status
      DONE = 'done'.freeze
    end

    UNBURNABLE_EPIC_LABEL_MATCHER = /\[U\]/
    PERMANENT_EPIC_LABEL_MATCHER = /\[P\]/

    def initialize(issue, report)
      super(issue)
      @report = report
    end

    def unburnable?
      epic_summary.match(UNBURNABLE_EPIC_LABEL_MATCHER)
    end

    def resolved_point
      done? ? completed_issue_resolved_point : incompleted_issue_resolved_point
    end

    def interrupted?
      permanent? || added_during_sprint? && created_in_sprint?
    end

    private

    def epic_summary
      @issue.dig('epicField', 'text')
    end

    def permanent?
      epic_summary.match(PERMANENT_EPIC_LABEL_MATCHER)
    end

    def done?
      status == Status::DONE
    end

    def status
      @issue.dig('status', 'statusCategory', 'key')
    end

    def completed_issue_resolved_point
      current_point || 0
    end

    def incompleted_issue_resolved_point
      return 0 if estimated_point.nil? || current_point.nil?
      return 0 if current_point == 0
      return 0 if estimated_point - current_point < 0

      estimated_point - current_point
    end

    def current_point
      @issue.dig('currentEstimateStatistic', 'statFieldValue', 'value')
    end

    def estimated_point
      @issue.dig('estimateStatistic', 'statFieldValue', 'value')
    end

    def added_during_sprint?
      @report.issueKeysAddedDuringSprint.include?(key)
    end

    def created_date
      return @created_date unless @created_date.nil?

      JiraUtil.new.client.Issue.find(key).created.to_date
    end

    def created_in_sprint?
      (@report.sprint.open_date..@report.sprint.close_date).include?(created_date)
    end

    def key
      @issue['key']
    end
  end
end
