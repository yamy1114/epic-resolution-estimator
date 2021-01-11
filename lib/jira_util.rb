class JiraUtil
  ACHIEVEMENT_SIZE = 5.freeze
  ESTIMATION_SIZE = 5.freeze
  MEMBER_COUNT = 5.freeze
  BASE_SPRINT_DAYS = 10.freeze

  EPIC_SEARCH_QUERY = "project = #{ENV.fetch('PROJECT_NAME')} AND issuetype = epic AND status != Done".freeze
  EPIC_SEARCH_MAX_RESULTS = 1_000

  TEXT_COLOR = {
      average: :white,
      worst: :blue,
      best: :light_red
  }.freeze

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
      t << [:sprint, *summarized_reports.map { |s| s[:sprint] }]
      t << :separator

      %i(days week_days sprint_size).each do |key|
        t << [key, *summarized_reports.map { |s| s[key] }]
      end

      t << :separator

      %i(resolved_points interrupted_points progress_points unburnable_points).each do |key|
        t << [key, *summarized_reports.map { |s| s[key].round(1) }]
      end
    end
  end

  def last_sprint_capacities(summarized_reports)
    summarized_reports.map do |report|
      report[:progress_points] / report[:sprint_size] * BASE_SPRINT_DAYS * MEMBER_COUNT
    end
  end

  def sprint_resolution_estimations(summarized_epics, sprint_capacity)
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

  def estimation_table(sprint_resolution_estimations_hash)
    sprint_indexes = sprint_resolution_estimations_hash[:average].map { |sp| sp[:sprint] }
    sprint_periods = sprint_resolution_estimations_hash[:average].map { |sp| sp[:period] }
    epic_summaries = sprint_resolution_estimations_hash[:average].first[:epics].map { |epic| epic[:summary] }
    sprint_count = sprint_resolution_estimations_hash[:average].size

    Terminal::Table.new do |t|
      t << [:sprint, *sprint_indexes]
      t << [:period, *sprint_periods]
      t << :separator

      epic_summaries.each_with_index do |epic_summary, epic_index|
        t << [
          epic_summary,
          *sprint_count.times.map do |sprint_index|
            points_for_display = sprint_resolution_estimations_hash.map do |type, estimations|
              resolved_points = estimations[sprint_index][:epics][epic_index][:resolved_points]
              resolved_points == 0 ? nil : resolved_points.round(1).to_s.send(TEXT_COLOR[type])
            end

            points_for_display.compact.join(' ')
          end
        ]
      end
    end
  end
end
