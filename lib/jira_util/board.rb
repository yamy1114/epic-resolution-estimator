class JiraUtil
  class Board < Base
    def achievement_sprints
      work_sprints = all_sprints.select(&:work?)
      last_closed_sprint_index = work_sprints.rindex(&:closed?)
      work_sprints.slice(last_closed_sprint_index - ACHIEVEMENT_SIZE + 1, ACHIEVEMENT_SIZE)
    end

    def working_sprint
      work_sprints = all_sprints.select(&:work?)
      work_sprints.find { |sprint| !sprint.closed? }
    end

    private

    def all_sprints
      return @all_sprints unless @all_sprints.nil?

      all_sprints = []
      start_at = 0
      max_results = 50

      loop do
        searched_sprints = @board.sprints(startAt: start_at)
        all_sprints += searched_sprints
        break if searched_sprints.empty?

        start_at += max_results
      end

      @all_sprints = all_sprints.map do |sprint|
        Sprint.new(sprint)
      end
    end
  end
end
