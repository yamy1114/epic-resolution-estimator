class JiraUtil
  class Sprint < Base
    module State
      CLOSED = 'closed'.freeze
    end

    WORK_SPRINT_MATCHER = /^Bear\/Lego Sprint \d+$/.freeze

    def work?
      @sprint.name.match(WORK_SPRINT_MATCHER)
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
        unburnable_points: report.unburnable_points,
        days: days,
        week_days: week_days,
        sprint_size: size
      }
    end

    def open_date
      startDate.to_date
    end

    def close_date
      completeDate.to_date
    end

    def index
      name.match(/\d+/)[0].to_i
    end

    private

    def days
      (close_date - open_date).to_i
    end

    def week_days
      open_date.upto(close_date).count { |date| !(date.saturday? || date.sunday?) }
    end

    def size
      week_days * MEMBER_COUNT
    end
  end
end
