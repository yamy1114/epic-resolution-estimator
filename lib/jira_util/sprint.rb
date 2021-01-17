class JiraUtil
  class Sprint < Base
    module State
      CLOSED = 'closed'.freeze
    end

    WORK_SPRINT_MATCHER = Regexp.new(ENV.fetch('WORK_SPRINT_MATCHER_STRING')).freeze

    def work?
      name.match(WORK_SPRINT_MATCHER)
    end

    def closed?
      @sprint.state == State::CLOSED
    end

    def report
      return @report unless @report.nil?

      Report.new(@sprint.sprint_report, self)
    end

    def summarized_report
      {
        sprint: index,
        resolved_points: report.resolved_points,
        interrupted_points: report.interrupted_points,
        progress_points: report.progress_points,
        work_days: TimeUtil.work_days(open_time, close_time),
      }
    end

    def open_time
      startDate.to_time
    end

    def close_time
      completeDate.to_time
    end

    def index
      name.match(/\d+/)[0].to_i
    end
  end
end
