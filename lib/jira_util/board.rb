class JiraUtil
  class Board < Base
    def achievement_sprints(achievement_size)
      work_sprints = all_sprints.select(&:work?)
      last_closed_sprint_index = work_sprints.rindex(&:closed?)
      work_sprints.slice(last_closed_sprint_index - achievement_size + 1, achievement_size)
    end

    private

    def all_sprints
      all_sprints = []
      start_at = 0
      max_results = 50

      loop do
        searched_sprints = @board.sprints(startAt: start_at)
        all_sprints += searched_sprints
        break if searched_sprints.empty?

        start_at += max_results
      end

      all_sprints.map do |sprint|
        Sprint.new(sprint)
      end
    end
  end
end
