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

      start_at = 100 # 古い Sprint は参照しなくて良いため start_at をある程度大きな値にしておく
      all_sprints = @board.sprints(startAt: start_at)

      @all_sprints = all_sprints.map do |sprint|
        Sprint.new(sprint)
      end
    end
  end
end
