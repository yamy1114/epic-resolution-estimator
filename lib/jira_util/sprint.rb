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
  end
end
