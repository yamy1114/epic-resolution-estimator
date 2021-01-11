class JiraUtil
  ACHIEVEMENT_SIZE = 5.freeze
  ESTIMATION_SIZE = 5.freeze
  MEMBER_COUNT = 5.freeze
  BASE_SPRINT_DAYS = 10.freeze

  EPIC_SEARCH_QUERY = "project = #{ENV.fetch('PROJECT_NAME')} AND issuetype = epic AND status != Done".freeze
  EPIC_SEARCH_MAX_RESULTS = 1_000

  def client
    return @client unless @client.nil?

    options = {
      username: ENV.fetch('ATTLASIAN_EMAIL'),
      password: ENV.fetch('ATTLASIAN_TOKEN'),
      site: ENV.fetch('ATTLASIAN_URL'),
      context_path: '',
      auth_type: :basic
    }

    @client = JIRA::Client.new(options)
  end

  def board
    return @board unless @board.nil?

    board = client.Board.all.find do |board|
      board.name == ENV.fetch('JIRA_BOARD_NAME')
    end

    @board = Board.new(board)
  end

  def epics
    return @epics unless @epics.nil?

    @epics = client.Issue.jql(EPIC_SEARCH_QUERY, max_results: EPIC_SEARCH_MAX_RESULTS).map do |epic|
      Epic.new(epic)
    end
  end

  def custom_fields
    return @custom_fields unless @custom_fields.nil?

    @custom_fields = CustomField.new(client.Field.map_fields)
  end

  def achievement_table(summarized_reports)
    Terminal::Table.new do |t|
      t << [:sprint, *summarized_reports.map { |s| s[:sprint] }, 'SUM']
      t << :separator

      %i(days week_days sprint_size).each do |key|
        t << [key, *summarized_reports.map { |s| s[key] }, summarized_reports.sum { |s| s[key] }]
      end

      t << :separator

      %i(resolved_points interrupted_points progress_points unburnable_points).each do |key|
        t << [key, *summarized_reports.map { |s| s[key].round(1) }, summarized_reports.sum { |s| s[key] }.round(1)]
      end
    end
  end

  def estimated_sprint_capacity(summarized_reports)
    progress_points_sum = summarized_reports.sum { |s| s[:progress_points] }
    sprint_size_sum = summarized_reports.sum { |s| s[:sprint_size] }
    progress_points_sum / sprint_size_sum * BASE_SPRINT_DAYS * MEMBER_COUNT
  end

  def future_sprint_estimations(summarized_epics, sprint_capacity)
    start_sprint_index = board.working_sprint.index
    start_sprint_open_date = board.working_sprint.open_date

    sprint_estimations = ESTIMATION_SIZE.times.map do |i|
      open_date = start_sprint_open_date + i * 2.weeks
      close_date = start_sprint_open_date + (i + 1) * 2.weeks - 1

      {
        sprint: start_sprint_index + i,
        epics: [],
        period: "#{open_date.month}/#{open_date.day}~#{close_date.month}/#{close_date.day}"
      }
    end

    summarized_epics.each do |epic|
      remaining_point = epic[:point] || 0.0

      sprint_estimations.each do |sprint_estimation|
        remaining_capacity = sprint_capacity - sprint_estimation[:epics].sum { |e| e[:resolved_points] || 0 }

        if remaining_point <= remaining_capacity
          resolved_point = remaining_point
          remaining_point = 0.0
        else
          resolved_point = remaining_capacity
          remaining_point -= remaining_capacity
        end

        sprint_estimation[:epics] << {
          summary: epic[:summary],
          resolved_points: resolved_point
        }
      end
    end

    sprint_estimations
  end

  def estimation_table(sprint_estimations)
    Terminal::Table.new do |t|
      t << [:sprint, *sprint_estimations.map { |sp| sp[:sprint] }]
      t << [:period, *sprint_estimations.map { |sp| sp[:period] }]
      t << :separator

      sprint_estimations.first[:epics].each_with_index do |epic, i|
        t << [
          epic[:summary],
          *sprint_estimations.map do |s|
            resolved_points = s[:epics][i][:resolved_points]
            resolved_points == 0 ? '' : resolved_points.round(1)
          end
        ]
      end
    end
  end
end
