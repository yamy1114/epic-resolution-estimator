class JiraUtil
  class Issue < Base
    module Status
      DONE = 'Done'.freeze
    end

    UNBURNABLE_EPIC_LABEL_MATCHER = /\[U\]/
    PERMANENT_EPIC_LABEL_MATCHER = /\[P\]/
    IMPROVEMENT_EPIC_LABEL_MATCHER = /improvement/i

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

    def improvement?
      epic_summary.match(IMPROVEMENT_EPIC_LABEL_MATCHER)
    end

    def epic_summary
      @issue.dig('epicField', 'text') || ''
    end

    private

    def permanent?
      epic_summary.match(PERMANENT_EPIC_LABEL_MATCHER)
    end

    def done?
      status == Status::DONE
    end

    def status
      @issue.dig('status', 'name')
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

      JiraUtil.get_instance.client.Issue.find(key).created.to_date
    end

    def created_in_sprint?
      (@report.sprint.open_time..@report.sprint.close_time).include?(created_date)
    end

    def key
      @issue['key']
    end
  end
end
